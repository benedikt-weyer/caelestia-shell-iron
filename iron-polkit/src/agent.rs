//! The polkit side: registers an `AuthenticationAgent` on the system bus and
//! turns each `BeginAuthentication` call into a dialog plus a helper session.

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result, bail};
use futures::channel::mpsc::UnboundedSender;
use nix::unistd::{Gid, Group, Uid, User};
use tokio::sync::{Notify, mpsc};
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};
use zbus::{Connection, DBusError, interface, proxy};

use crate::helper::{Outcome, Session, Transport};
use crate::protocol::{Request, UiEvent};

/// Where our agent object is exported. Only has to be unique on our own connection.
const AGENT_PATH: &str = "/org/iron/PolicyKit1/AuthenticationAgent";

type Identity = (String, HashMap<String, OwnedValue>);
type Subject<'a> = (&'a str, HashMap<&'a str, Value<'a>>);

#[proxy(
    interface = "org.freedesktop.PolicyKit1.Authority",
    default_service = "org.freedesktop.PolicyKit1",
    default_path = "/org/freedesktop/PolicyKit1/Authority"
)]
trait Authority {
    fn register_authentication_agent(
        &self,
        subject: &Subject<'_>,
        locale: &str,
        object_path: &str,
    ) -> zbus::Result<()>;

    fn unregister_authentication_agent(
        &self,
        subject: &Subject<'_>,
        object_path: &str,
    ) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.login1.Manager",
    default_service = "org.freedesktop.login1",
    default_path = "/org/freedesktop/login1"
)]
trait LoginManager {
    fn get_session_by_pid(&self, pid: u32) -> zbus::Result<OwnedObjectPath>;
    fn get_user(&self, uid: u32) -> zbus::Result<OwnedObjectPath>;
}

#[proxy(
    interface = "org.freedesktop.login1.User",
    default_service = "org.freedesktop.login1"
)]
trait LoginUser {
    #[zbus(property)]
    fn display(&self) -> zbus::Result<(String, OwnedObjectPath)>;

    #[zbus(property)]
    fn sessions(&self) -> zbus::Result<Vec<(String, OwnedObjectPath)>>;
}

#[proxy(
    interface = "org.freedesktop.login1.Session",
    default_service = "org.freedesktop.login1"
)]
trait LoginSession {
    #[zbus(property)]
    fn id(&self) -> zbus::Result<String>;
}

#[derive(Debug, DBusError)]
#[zbus(prefix = "org.freedesktop.PolicyKit1.Error")]
enum AgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Failed(String),
    Cancelled(String),
}

type Cancels = Arc<Mutex<HashMap<String, Arc<Notify>>>>;

struct Agent {
    ui: UnboundedSender<UiEvent>,
    transport: Transport,
    current_uid: Uid,
    cancels: Cancels,
}

/// Tells the UI a request is over however its handler exits - including when
/// the method future is dropped because the bus connection went away.
struct EndGuard {
    ui: UnboundedSender<UiEvent>,
    cancels: Cancels,
    cookie: String,
}

impl Drop for EndGuard {
    fn drop(&mut self) {
        if let Ok(mut cancels) = self.cancels.lock() {
            cancels.remove(&self.cookie);
        }
        let _ = self.ui.unbounded_send(UiEvent::End {
            cookie: std::mem::take(&mut self.cookie),
        });
    }
}

#[interface(name = "org.freedesktop.PolicyKit1.AuthenticationAgent")]
impl Agent {
    async fn begin_authentication(
        &self,
        action_id: String,
        message: String,
        _icon_name: String,
        details: HashMap<String, String>,
        cookie: String,
        identities: Vec<Identity>,
    ) -> Result<(), AgentError> {
        let user = pick_user(&identities, self.current_uid)
            .ok_or_else(|| AgentError::Failed("no usable identity to authenticate as".into()))?;
        tracing::info!(%action_id, %user, "authentication requested");

        let cancel = Arc::new(Notify::new());
        self.cancels
            .lock()
            .map_err(|_| AgentError::Failed("agent state poisoned".into()))?
            .insert(cookie.clone(), cancel.clone());
        let _guard = EndGuard {
            ui: self.ui.clone(),
            cancels: self.cancels.clone(),
            cookie: cookie.clone(),
        };

        let (answers_tx, mut answers_rx) = mpsc::unbounded_channel();
        let _ = self.ui.unbounded_send(UiEvent::Begin {
            request: Request {
                cookie: cookie.clone(),
                action_id,
                message,
                details: details.into_iter().collect::<BTreeMap<_, _>>(),
                user: user.clone(),
            },
            answers: answers_tx,
        });

        let outcome = Session {
            transport: &self.transport,
            user: &user,
            cookie: &cookie,
            ui: &self.ui,
            answers: &mut answers_rx,
            cancel: &cancel,
        }
        .run()
        .await;

        match outcome {
            Ok(Outcome::Authorized) => Ok(()),
            // polkit expects this exact error when the agent gave up on purpose.
            Ok(Outcome::Cancelled) => Err(AgentError::Cancelled("dismissed by the user".into())),
            Err(error) => {
                tracing::error!(%error, "authentication failed");
                Err(AgentError::Failed(format!("{error:#}")))
            }
        }
    }

    async fn cancel_authentication(&self, cookie: String) {
        let cancel = self
            .cancels
            .lock()
            .ok()
            .and_then(|cancels| cancels.get(&cookie).cloned());
        if let Some(cancel) = cancel {
            tracing::info!("authentication cancelled by polkit");
            cancel.notify_one();
        }
    }
}

/// Picks the account to authenticate as. Polkit hands us "identities that
/// would be accepted" (usually a group like `wheel`): prefer ourselves if
/// eligible, otherwise the first eligible account.
fn pick_user(identities: &[Identity], current_uid: Uid) -> Option<String> {
    let mut candidates = Vec::new();
    for (kind, props) in identities {
        match kind.as_str() {
            "unix-user" => {
                if let Some(uid) = prop_u32(props, "uid")
                    && let Ok(Some(user)) = User::from_uid(Uid::from_raw(uid))
                {
                    candidates.push(user.name);
                }
            }
            "unix-group" => {
                if let Some(gid) = prop_u32(props, "gid")
                    && let Ok(Some(group)) = Group::from_gid(Gid::from_raw(gid))
                {
                    candidates.extend(group.mem);
                }
            }
            _ => {}
        }
    }

    let me = User::from_uid(current_uid)
        .ok()
        .flatten()
        .map(|user| user.name);
    match me {
        Some(me) if candidates.contains(&me) => Some(me),
        _ => candidates.into_iter().next(),
    }
}

fn prop_u32(props: &HashMap<String, OwnedValue>, key: &str) -> Option<u32> {
    props.get(key).and_then(|value| u32::try_from(value).ok())
}

/// The logind session polkit will match our agent against. This shell runs as
/// a systemd user service, which isn't inside any session scope, so fall back
/// to the user's display session - the same thing polkitd does for callers
/// that aren't in a session either.
async fn session_id(conn: &Connection, uid: Uid) -> Result<String> {
    if let Ok(id) = std::env::var("XDG_SESSION_ID")
        && !id.is_empty()
    {
        return Ok(id);
    }

    let manager = LoginManagerProxy::new(conn).await?;

    if let Ok(path) = manager.get_session_by_pid(std::process::id()).await {
        let session = LoginSessionProxy::builder(conn).path(path)?.build().await?;
        return Ok(session.id().await?);
    }

    let user_path = manager
        .get_user(uid.as_raw())
        .await
        .context("logind doesn't know this user")?;
    let user = LoginUserProxy::builder(conn)
        .path(user_path)?
        .build()
        .await?;

    let (display_id, _) = user.display().await?;
    if !display_id.is_empty() {
        return Ok(display_id);
    }
    match user.sessions().await?.into_iter().next() {
        Some((id, _)) => Ok(id),
        None => bail!("user has no logind session to register the agent for"),
    }
}

fn locale() -> String {
    ["LC_ALL", "LC_MESSAGES", "LANG"]
        .iter()
        .find_map(|var| std::env::var(var).ok().filter(|value| !value.is_empty()))
        .unwrap_or_else(|| "en_US.UTF-8".into())
}

/// Registers the agent and serves requests until the process is told to stop.
pub async fn run(ui: UnboundedSender<UiEvent>, transport: Transport) -> Result<()> {
    let current_uid = Uid::current();
    let agent = Agent {
        ui,
        transport,
        current_uid,
        cancels: Cancels::default(),
    };

    let conn = zbus::connection::Builder::system()?
        .serve_at(AGENT_PATH, agent)?
        .build()
        .await
        .context("failed to connect to the system bus")?;

    let session_id = session_id(&conn, current_uid).await?;
    let subject: Subject<'_> = (
        "unix-session",
        HashMap::from([("session-id", Value::from(session_id.clone()))]),
    );

    let authority = AuthorityProxy::new(&conn).await?;
    authority
        .register_authentication_agent(&subject, &locale(), AGENT_PATH)
        .await
        .context("polkit refused the agent registration (is another agent already running?)")?;
    tracing::info!(%session_id, "registered as polkit authentication agent");

    wait_for_shutdown().await?;

    if let Err(error) = authority
        .unregister_authentication_agent(&subject, AGENT_PATH)
        .await
    {
        tracing::warn!(%error, "failed to unregister agent");
    }
    Ok(())
}

async fn wait_for_shutdown() -> Result<()> {
    use tokio::signal::unix::{SignalKind, signal};

    let mut term = signal(SignalKind::terminate())?;
    let mut int = signal(SignalKind::interrupt())?;
    tokio::select! {
        _ = term.recv() => {}
        _ = int.recv() => {}
    }
    Ok(())
}
