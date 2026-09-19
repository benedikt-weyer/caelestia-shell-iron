mod agent;
mod helper;
mod protocol;
mod ui;

use tracing_subscriber::EnvFilter;

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .init();

    let transport = helper::Transport::detect()?;
    tracing::info!(?transport, "using polkit helper");

    // Requests that arrive before the UI is up just wait in this channel.
    let (ui_tx, ui_rx) = futures::channel::mpsc::unbounded();

    // The D-Bus/PAM side runs on its own runtime; iced owns the main thread.
    std::thread::Builder::new()
        .name("polkit-agent".into())
        .spawn(move || {
            let runtime = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("failed to build tokio runtime");
            let result = runtime.block_on(agent::run(ui_tx, transport));
            match result {
                Ok(()) => std::process::exit(0),
                Err(error) => {
                    tracing::error!("{error:#}");
                    std::process::exit(1);
                }
            }
        })?;

    ui::run(ui_rx)
}
