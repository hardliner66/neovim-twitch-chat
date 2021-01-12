use crate::args;
use crate::event::Event;

use log::*;

use neovim_lib::{Handler, RequestHandler, Value};

use std::sync::mpsc;

pub struct NeovimHandler(pub mpsc::Sender<Event>);

impl NeovimHandler {
    pub fn parse_receive_message(&mut self, args: &Vec<Value>) -> Result<Event, String> {
        if 1 != args.len() {
            return Err(format!(
                "Wrong number of arguments for 'ReceiveMessage'.  Expected 1, found \
                 {}",
                args.len()
            ));
        }

        let msg = args::parse_string(&args[0])?;

        Ok(Event::ReceivedMessage(msg))
    }
}

impl Handler for NeovimHandler {
    fn handle_notify(&mut self, name: &str, args: Vec<Value>) {
        info!("event: {}", name);
        match name {
            "received-message" => {
                if let Ok(event) = self.parse_receive_message(&args) {
                    info!("receive message: {:?}", event);
                    if let Err(reason) = self.0.send(event) {
                        error!("{}", reason);
                    }
                }
            }
            "quit" => {
                if let Err(reason) = self.0.send(Event::Quit) {
                    error!("{}", reason);
                }
            }
            _ => {}
        }
    }
}

impl RequestHandler for NeovimHandler {
    fn handle_request(&mut self, _name: &str, _args: Vec<Value>) -> Result<Value, Value> {
        Err(Value::from("not implemented"))
    }
}
