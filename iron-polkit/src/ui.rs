//! The password prompt: a dimmed full-screen overlay layer surface with a
//! centred dialog. Only one dialog is shown at a time; further requests queue.

use std::collections::VecDeque;
use std::sync::Mutex;

use futures::channel::mpsc::UnboundedReceiver;
use iced::widget::{button, column, container, row, text, text_input};
use iced::{Background, Border, Color, Element, Event, Font, Length, Subscription, Task, Theme};
use iced::{event, font, keyboard, widget, window};
use iced_exwlshell::reexport::{
    Anchor, KeyboardInteractivity, Layer, LayerSize, NewLayerShellSettings, OutputOption,
};
use iced_exwlshell::settings::{LayerShellSettings, Settings, StartMode};
use iced_exwlshell::{daemon, to_exwlshell_message};
use tokio::sync::mpsc::UnboundedSender;

use crate::protocol::{Answer, Request, UiEvent};

const NAMESPACE: &str = "iron-polkit";
const PASSWORD_ID: &str = "iron-polkit-password";
const RETRY_TEXT: &str = "Sorry, that didn't work. Please try again.";

#[to_exwlshell_message]
#[derive(Debug, Clone)]
enum Message {
    Agent(UiEvent),
    Input(String),
    Submit,
    Cancel,
}

struct Status {
    text: String,
    is_error: bool,
}

struct Prompt {
    text: String,
    echo: bool,
}

struct Dialog {
    request: Request,
    answers: UnboundedSender<Answer>,
    window: Option<window::Id>,
    prompt: Option<Prompt>,
    status: Option<Status>,
    input: String,
    /// A response was sent and PAM hasn't come back with a verdict yet.
    busy: bool,
}

#[derive(Default)]
struct App {
    dialogs: VecDeque<Dialog>,
}

impl App {
    fn dialog_mut(&mut self, cookie: &str) -> Option<&mut Dialog> {
        self.dialogs
            .iter_mut()
            .find(|dialog| dialog.request.cookie == cookie)
    }

    /// Opens the overlay for the dialog at the front of the queue, if it has none yet.
    fn open_front(&mut self) -> Task<Message> {
        let Some(dialog) = self.dialogs.front_mut() else {
            return Task::none();
        };
        if dialog.window.is_some() {
            return Task::none();
        }

        let (id, open) = Message::layershell_open(NewLayerShellSettings {
            size: LayerSize::FILL,
            layer: Layer::Overlay,
            anchor: Anchor::all(),
            exclusive_zone: Some(-1),
            keyboard_interactivity: KeyboardInteractivity::Exclusive,
            output_option: OutputOption::LastOutput,
            namespace: Some(NAMESPACE.to_owned()),
            ..Default::default()
        });
        dialog.window = Some(id);
        open.chain(widget::operation::focus(PASSWORD_ID))
    }

    fn on_event(&mut self, event: UiEvent) -> Task<Message> {
        match event {
            UiEvent::Begin { request, answers } => {
                self.dialogs.push_back(Dialog {
                    request,
                    answers,
                    window: None,
                    prompt: None,
                    status: None,
                    input: String::new(),
                    busy: false,
                });
                self.open_front()
            }
            UiEvent::Prompt {
                cookie,
                prompt,
                echo,
            } => {
                if let Some(dialog) = self.dialog_mut(&cookie) {
                    dialog.prompt = Some(Prompt { text: prompt, echo });
                    dialog.busy = false;
                }
                widget::operation::focus(PASSWORD_ID)
            }
            UiEvent::Info {
                cookie,
                text,
                is_error,
            } => {
                if let Some(dialog) = self.dialog_mut(&cookie) {
                    dialog.status = Some(Status { text, is_error });
                }
                Task::none()
            }
            UiEvent::Retry { cookie } => {
                if let Some(dialog) = self.dialog_mut(&cookie) {
                    dialog.status = Some(Status {
                        text: RETRY_TEXT.to_owned(),
                        is_error: true,
                    });
                    dialog.prompt = None;
                    dialog.busy = false;
                }
                Task::none()
            }
            UiEvent::End { cookie } => {
                let Some(index) = self
                    .dialogs
                    .iter()
                    .position(|dialog| dialog.request.cookie == cookie)
                else {
                    return Task::none();
                };
                let close = match self.dialogs.remove(index).and_then(|dialog| dialog.window) {
                    Some(id) => Task::done(Message::RemoveWindow(id)),
                    None => Task::none(),
                };
                Task::batch([close, self.open_front()])
            }
        }
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Agent(event) => return self.on_event(event),
            Message::Input(input) => {
                if let Some(dialog) = self.dialogs.front_mut()
                    && !dialog.busy
                {
                    dialog.input = input;
                }
            }
            Message::Submit => {
                if let Some(dialog) = self.dialogs.front_mut()
                    && dialog.prompt.is_some()
                    && !dialog.busy
                {
                    let response = std::mem::take(&mut dialog.input);
                    if dialog.answers.send(Answer::Response(response)).is_ok() {
                        dialog.busy = true;
                        dialog.prompt = None;
                        dialog.status = None;
                    }
                }
            }
            Message::Cancel => {
                // The agent replies with `End`, which is what removes the dialog.
                if let Some(dialog) = self.dialogs.front_mut() {
                    let _ = dialog.answers.send(Answer::Cancel);
                    dialog.busy = true;
                }
            }
            // Layer-shell actions are consumed by the runtime before reaching us.
            _ => {}
        }
        Task::none()
    }

    fn view(&self, window: window::Id) -> Element<'_, Message> {
        let Some(dialog) = self
            .dialogs
            .iter()
            .find(|dialog| dialog.window == Some(window))
        else {
            return widget::space().into();
        };

        let backdrop = container(container(dialog_card(dialog)).style(card_style))
            .center_x(Length::Fill)
            .center_y(Length::Fill)
            .style(|_| container::Style {
                background: Some(Background::Color(Color::from_rgba(0.0, 0.0, 0.0, 0.55))),
                ..Default::default()
            });
        backdrop.into()
    }

    fn subscription(&self) -> Subscription<Message> {
        event::listen_with(|event, _status, _window| match event {
            Event::Keyboard(keyboard::Event::KeyPressed {
                key: keyboard::Key::Named(keyboard::key::Named::Escape),
                ..
            }) => Some(Message::Cancel),
            _ => None,
        })
    }
}

fn bold() -> Font {
    Font {
        weight: font::Weight::Bold,
        ..Font::DEFAULT
    }
}

fn card_style(theme: &Theme) -> container::Style {
    let palette = theme.extended_palette();
    container::Style {
        background: Some(Background::Color(palette.background.base.color)),
        border: Border {
            color: palette.background.strong.color,
            width: 1.0,
            radius: 16.0.into(),
        },
        ..Default::default()
    }
}

fn dialog_card(dialog: &Dialog) -> Element<'_, Message> {
    let request = &dialog.request;

    let mut content = column![
        text("Authentication required").size(22).font(bold()),
        text(&request.message).size(15),
    ]
    .spacing(6);

    // pkexec passes what it is about to run; other callers don't.
    for (label, key) in [("Program", "program"), ("Command", "command_line")] {
        if let Some(value) = request.details.get(key) {
            content = content.push(
                text(format!("{label}: {value}"))
                    .size(12)
                    .style(text::secondary),
            );
        }
    }
    content = content.push(text(&request.action_id).size(12).style(text::secondary));

    let (placeholder, secure) = match &dialog.prompt {
        Some(prompt) => (
            prompt.text.trim().trim_end_matches(':').trim(),
            !prompt.echo,
        ),
        None => ("Password", true),
    };
    let ready = dialog.prompt.is_some() && !dialog.busy;

    let mut input = text_input(placeholder, &dialog.input)
        .id(PASSWORD_ID)
        .secure(secure)
        .padding(10)
        .size(16);
    if ready {
        input = input.on_input(Message::Input).on_submit(Message::Submit);
    }

    let status: Element<'_, Message> = match (&dialog.status, dialog.busy) {
        (Some(status), _) if status.is_error => {
            text(&status.text).size(13).style(text::danger).into()
        }
        (Some(status), _) => text(&status.text).size(13).into(),
        (None, true) => text("Authenticating…")
            .size(13)
            .style(text::secondary)
            .into(),
        (None, false) => text("").size(13).into(),
    };

    content = content
        .push(text(format!("Authenticating as {}", request.user)).size(13))
        .push(input)
        .push(status)
        .push(
            row![
                button(text("Cancel"))
                    .on_press(Message::Cancel)
                    .style(button::secondary),
                button(text("Authenticate"))
                    .on_press_maybe(ready.then_some(Message::Submit))
                    .style(button::primary),
            ]
            .spacing(8),
        )
        .spacing(10);

    container(content).padding(24).width(420).into()
}

pub fn run(events: UnboundedReceiver<UiEvent>) -> anyhow::Result<()> {
    // `boot` is `Fn`, so the receiver has to be moved out from behind a lock.
    let events = Mutex::new(Some(events));

    daemon(
        move || {
            let events = events
                .lock()
                .ok()
                .and_then(|mut events| events.take())
                .expect("boot runs once");
            (App::default(), Task::stream(events).map(Message::Agent))
        },
        NAMESPACE,
        App::update,
        App::view,
    )
    .subscription(App::subscription)
    .theme(|_: &App, _| Theme::CatppuccinMocha)
    .style(|_, theme: &Theme| iced::theme::Style {
        background_color: Color::TRANSPARENT,
        text_color: theme.palette().text,
    })
    .settings(Settings {
        id: Some(NAMESPACE.to_owned()),
        layer_settings: LayerShellSettings {
            // No surface until a request arrives.
            start_mode: StartMode::Background,
            ..Default::default()
        },
        ..Default::default()
    })
    .run()?;
    Ok(())
}
