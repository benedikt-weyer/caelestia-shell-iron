//! Messages exchanged between the D-Bus/PAM side (`agent`, `helper`) and the UI.

use std::collections::BTreeMap;

use tokio::sync::mpsc::UnboundedSender;

/// What polkit asked us to authenticate, as shown in the dialog.
#[derive(Debug, Clone)]
pub struct Request {
    pub cookie: String,
    pub action_id: String,
    pub message: String,
    pub details: BTreeMap<String, String>,
    /// The account we authenticate as (may differ from the caller's for root prompts).
    pub user: String,
}

/// Agent -> UI.
#[derive(Debug, Clone)]
pub enum UiEvent {
    /// A new authentication request. `answers` is how the UI talks back to it.
    Begin {
        request: Request,
        answers: UnboundedSender<Answer>,
    },
    /// PAM wants input. `echo` is false for passwords.
    Prompt {
        cookie: String,
        prompt: String,
        echo: bool,
    },
    /// PAM text/error message to show the user.
    Info {
        cookie: String,
        text: String,
        is_error: bool,
    },
    /// The attempt failed but polkit-agent-helper is being restarted for another go.
    Retry { cookie: String },
    /// The request is over (authorized, cancelled or failed): drop the dialog.
    End { cookie: String },
}

/// UI -> agent.
#[derive(Debug)]
pub enum Answer {
    Response(String),
    Cancel,
}
