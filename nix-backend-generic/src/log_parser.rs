use serde::Deserialize;
use serde_json::Value;

/// One `nix ... --log-format internal-json` line, decoded just enough to
/// pull out something worth showing the user. Nix's own docs call this
/// format internal/unstable, so we deliberately only look at the handful of
/// fields that have been stable for years (msg text, start text, resProgress
/// counters) and fall back to the raw line for everything else.
#[derive(Deserialize)]
#[serde(tag = "action", rename_all = "lowercase")]
enum NixLogLine {
    Msg {
        msg: String,
    },
    Start {
        #[serde(default)]
        text: String,
    },
    Result {
        #[serde(rename = "type", default)]
        kind: i32,
        #[serde(default)]
        fields: Vec<Value>,
    },
    #[serde(other)]
    Other,
}

/// `resProgress` result type, see nix's `src/libmain/progress-bar.cc`.
const RESULT_TYPE_PROGRESS: i32 = 104;

pub struct ParsedLine {
    pub message: Option<String>,
    pub fraction_done: Option<f64>,
}

impl ParsedLine {
    fn empty() -> Self {
        Self { message: None, fraction_done: None }
    }
}

/// Parses one line of a nix subprocess's output (json-log or plain text)
/// into something a `ProgressEvent` can carry. Never fails: an unrecognised
/// or malformed line is just surfaced as its own message.
pub fn parse_line(line: &str) -> ParsedLine {
    let line = line.trim_end();
    if line.is_empty() {
        return ParsedLine::empty();
    }

    let Some(json) = line.strip_prefix("@nix ") else {
        return ParsedLine { message: Some(line.to_owned()), fraction_done: None };
    };

    let Ok(parsed) = serde_json::from_str::<NixLogLine>(json) else {
        return ParsedLine { message: Some(json.to_owned()), fraction_done: None };
    };

    match parsed {
        NixLogLine::Msg { msg } if !msg.is_empty() => ParsedLine { message: Some(msg), fraction_done: None },
        NixLogLine::Start { text } if !text.is_empty() => ParsedLine { message: Some(text), fraction_done: None },
        NixLogLine::Result { kind, fields } if kind == RESULT_TYPE_PROGRESS => {
            let done = fields.first().and_then(Value::as_f64);
            let expected = fields.get(1).and_then(Value::as_f64);
            let fraction = match (done, expected) {
                (Some(done), Some(expected)) if expected > 0.0 => Some((done / expected).clamp(0.0, 1.0)),
                _ => None,
            };
            ParsedLine { message: None, fraction_done: fraction }
        }
        _ => ParsedLine::empty(),
    }
}
