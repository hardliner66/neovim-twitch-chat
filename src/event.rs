use std::fmt;

pub enum Event {
    ReceivedMessage(String),
    Quit,
}

impl fmt::Debug for Event {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        use Event::*;

        match self {
            ReceivedMessage(msg) => write!(f, "Received Message: {}", msg),
            &Quit => write!(f, "Event::Quit"),
        }
    }
}
