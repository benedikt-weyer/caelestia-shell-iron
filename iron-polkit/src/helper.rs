//! Drives `polkit-agent-helper-1`, the root helper that runs the PAM conversation.
//!
//! Only that helper is allowed to hand the authentication result back to
//! polkitd via `AuthenticationAgentResponse2`, so an agent never talks to PAM
//! itself. The protocol is line based: we send the cookie, then read `PAM_*`
//! prompt lines and a final `SUCCESS`/`FAILURE`, answering prompts with a
//! single line.
//!
//! polkit >= 126 exposes the helper on a socket-activated unix socket (no
//! setuid binary needed, and NixOS no longer ships the setuid wrapper); older
//! setups spawn the setuid binary and talk over its stdio. Same protocol, two
//! transports - this mirrors what libpolkit-agent does.

use std::path::{Path, PathBuf};
use std::process::Stdio;

use anyhow::{Context, Result, bail};
use futures::channel::mpsc::UnboundedSender;
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::process::{Child, Command};
use tokio::sync::Notify;
use tokio::sync::mpsc::UnboundedReceiver;

use crate::protocol::{Answer, UiEvent};

const HELPER_NAME: &str = "polkit-agent-helper-1";

const HELPER_SOCKET: &str = "/run/polkit/agent-helper.socket";

/// Setuid copies of the helper, for polkit versions without the socket. The
/// copy inside a Nix store path is not setuid, so it can't be used.
const SETUID_CANDIDATES: &[&str] = &[
    "/run/wrappers/bin/polkit-agent-helper-1",
    "/usr/lib/polkit-1/polkit-agent-helper-1",
    "/usr/libexec/polkit-agent-helper-1",
    "/usr/lib/policykit-1/polkit-agent-helper-1",
];

type Reader = Box<dyn AsyncRead + Send + Unpin>;
type Writer = Box<dyn AsyncWrite + Send + Unpin>;

/// How to reach the helper.
#[derive(Debug, Clone)]
pub enum Transport {
    Socket(PathBuf),
    Spawn(PathBuf),
}

impl Transport {
    /// `IRON_POLKIT_HELPER` forces a specific setuid binary; otherwise prefer
    /// the socket, like libpolkit-agent does.
    pub fn detect() -> Result<Self> {
        if let Some(path) = std::env::var_os("IRON_POLKIT_HELPER") {
            return Ok(Self::Spawn(PathBuf::from(path)));
        }

        let socket = Path::new(HELPER_SOCKET);
        if socket.exists() {
            return Ok(Self::Socket(socket.to_path_buf()));
        }

        SETUID_CANDIDATES
            .iter()
            .map(Path::new)
            .find(|path| path.exists())
            .map(|path| Self::Spawn(path.to_path_buf()))
            .with_context(|| {
                format!(
                    "no {HELPER_NAME} found: neither {HELPER_SOCKET} nor a setuid binary \
                     (set IRON_POLKIT_HELPER to one)"
                )
            })
    }

    fn describe(&self) -> String {
        match self {
            Self::Socket(path) | Self::Spawn(path) => path.display().to_string(),
        }
    }

    async fn open(&self, user: &str) -> Result<Channel> {
        match self {
            Self::Socket(path) => {
                let stream = UnixStream::connect(path)
                    .await
                    .with_context(|| format!("failed to connect to {}", path.display()))?;
                let (reader, mut writer) = stream.into_split();
                // The socket-activated helper has no argv: it reads the user first.
                send_line(&mut writer, user).await?;
                Ok(Channel {
                    reader: Box::new(reader),
                    writer: Box::new(writer),
                    _child: None,
                })
            }
            Self::Spawn(path) => {
                let mut child = Command::new(path)
                    .arg(user)
                    .stdin(Stdio::piped())
                    .stdout(Stdio::piped())
                    .kill_on_drop(true)
                    .spawn()
                    .with_context(|| format!("failed to spawn {}", path.display()))?;
                let writer = child.stdin.take().context("helper has no stdin")?;
                let reader = child.stdout.take().context("helper has no stdout")?;
                Ok(Channel {
                    reader: Box::new(reader),
                    writer: Box::new(writer),
                    _child: Some(child),
                })
            }
        }
    }
}

/// One live conversation with the helper. Dropping it ends the attempt
/// (closes the socket / kills the spawned helper).
struct Channel {
    reader: Reader,
    writer: Writer,
    _child: Option<Child>,
}

async fn send_line(writer: &mut (impl AsyncWrite + Unpin), line: &str) -> Result<()> {
    writer.write_all(line.as_bytes()).await?;
    writer.write_all(b"\n").await?;
    writer.flush().await?;
    Ok(())
}

#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    Authorized,
    Cancelled,
}

enum Attempt {
    Success,
    Failure,
    Cancelled,
}

#[derive(Debug, PartialEq, Eq)]
enum Line<'a> {
    Prompt { text: &'a str, echo: bool },
    Info(&'a str),
    Error(&'a str),
    Success,
    Failure,
    Unknown,
}

fn parse_line(line: &str) -> Line<'_> {
    if line == "SUCCESS" {
        Line::Success
    } else if line == "FAILURE" {
        Line::Failure
    } else if let Some(text) = line.strip_prefix("PAM_PROMPT_ECHO_OFF ") {
        Line::Prompt { text, echo: false }
    } else if let Some(text) = line.strip_prefix("PAM_PROMPT_ECHO_ON ") {
        Line::Prompt { text, echo: true }
    } else if let Some(text) = line.strip_prefix("PAM_ERROR_MSG ") {
        Line::Error(text)
    } else if let Some(text) = line.strip_prefix("PAM_TEXT_INFO ") {
        Line::Info(text)
    } else {
        Line::Unknown
    }
}

/// Everything one authentication needs to talk to the UI and to be cancelled.
pub struct Session<'a> {
    pub transport: &'a Transport,
    pub user: &'a str,
    pub cookie: &'a str,
    pub ui: &'a UnboundedSender<UiEvent>,
    pub answers: &'a mut UnboundedReceiver<Answer>,
    pub cancel: &'a Notify,
}

impl Session<'_> {
    /// Authenticates until the user succeeds or cancels. A wrong password
    /// starts a fresh helper conversation (it ends after one failed attempt),
    /// like polkit's own agents do.
    pub async fn run(&mut self) -> Result<Outcome> {
        loop {
            match self.attempt().await? {
                Attempt::Success => return Ok(Outcome::Authorized),
                Attempt::Cancelled => return Ok(Outcome::Cancelled),
                Attempt::Failure => self.send(UiEvent::Retry {
                    cookie: self.cookie.to_owned(),
                }),
            }
        }
    }

    fn send(&self, event: UiEvent) {
        // The UI only goes away when the whole process is shutting down.
        let _ = self.ui.unbounded_send(event);
    }

    async fn attempt(&mut self) -> Result<Attempt> {
        let Channel {
            reader,
            mut writer,
            _child,
        } = self.transport.open(self.user).await?;
        let mut lines = BufReader::new(reader).lines();

        tracing::debug!(transport = %self.transport.describe(), "authenticating");
        send_line(&mut writer, self.cookie).await?;

        loop {
            tokio::select! {
                line = lines.next_line() => {
                    let Some(line) = line.context("failed to read from helper")? else {
                        bail!("{HELPER_NAME} closed the connection without a verdict");
                    };
                    tracing::debug!(%line, "helper says");
                    match parse_line(&line) {
                        Line::Success => return Ok(Attempt::Success),
                        Line::Failure => return Ok(Attempt::Failure),
                        Line::Prompt { text, echo } => self.send(UiEvent::Prompt {
                            cookie: self.cookie.to_owned(),
                            prompt: text.to_owned(),
                            echo,
                        }),
                        Line::Info(text) => self.send(UiEvent::Info {
                            cookie: self.cookie.to_owned(),
                            text: text.to_owned(),
                            is_error: false,
                        }),
                        Line::Error(text) => self.send(UiEvent::Info {
                            cookie: self.cookie.to_owned(),
                            text: text.to_owned(),
                            is_error: true,
                        }),
                        Line::Unknown => tracing::debug!(%line, "unrecognised helper output"),
                    }
                }
                answer = self.answers.recv() => match answer {
                    Some(Answer::Response(response)) => send_line(&mut writer, &response).await?,
                    // Dropped sender means the UI is gone; nobody can answer anymore.
                    Some(Answer::Cancel) | None => return Ok(Attempt::Cancelled),
                },
                () = self.cancel.notified() => return Ok(Attempt::Cancelled),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_helper_protocol() {
        assert_eq!(
            parse_line("PAM_PROMPT_ECHO_OFF Password: "),
            Line::Prompt {
                text: "Password: ",
                echo: false
            }
        );
        assert_eq!(
            parse_line("PAM_PROMPT_ECHO_ON Username: "),
            Line::Prompt {
                text: "Username: ",
                echo: true
            }
        );
        assert_eq!(parse_line("PAM_ERROR_MSG nope"), Line::Error("nope"));
        assert_eq!(
            parse_line("PAM_TEXT_INFO touch the reader"),
            Line::Info("touch the reader")
        );
        assert_eq!(parse_line("SUCCESS"), Line::Success);
        assert_eq!(parse_line("FAILURE"), Line::Failure);
        assert_eq!(parse_line("garbage"), Line::Unknown);
    }
}
