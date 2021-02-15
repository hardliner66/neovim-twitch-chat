mod args;
mod event;
mod handler;

use twitch_irc::login::{CredentialsPair, StaticLoginCredentials};
use twitch_irc::message::ServerMessage;
use twitch_irc::ClientConfig;
use twitch_irc::TCPTransport;
use twitch_irc::TwitchIRCClient;

use crate::event::Event;
use crate::handler::NeovimHandler;
use std::sync::{Arc, Mutex};

use log::*;

use neovim_lib::neovim::Neovim;
use neovim_lib::neovim_api::NeovimApi;
use neovim_lib::session::Session;

use simplelog::{Config, LogLevel, LogLevelFilter, WriteLogger};

use std::error::Error;
use std::sync::mpsc;

#[tokio::main]
async fn main() {
    use std::process;

    init_logging().expect("twitch chat: unable to initialize logger.");

    match start_program().await {
        Ok(_) => process::exit(0),

        Err(msg) => {
            error!("{}", msg);
            process::exit(1);
        }
    };
}

fn init_logging() -> Result<(), Box<dyn Error>> {
    use std::env;
    use std::env::VarError;
    use std::fs::File;

    let log_level_filter = match env::var("LOG_LEVEL")
        .unwrap_or(String::from("error"))
        .to_lowercase()
        .as_ref()
    {
        "debug" => LogLevelFilter::Debug,
        "error" => LogLevelFilter::Error,
        "info" => LogLevelFilter::Info,
        "off" => LogLevelFilter::Off,
        "trace" => LogLevelFilter::Trace,
        "warn" => LogLevelFilter::Warn,
        _ => LogLevelFilter::Off,
    };

    let config = Config {
        time: Some(LogLevel::Error),
        level: Some(LogLevel::Error),
        target: Some(LogLevel::Error),
        location: Some(LogLevel::Error),
    };

    let filepath = match env::var("LOG_FILE") {
        Err(err) => match err {
            VarError::NotPresent => return Ok(()),
            e @ VarError::NotUnicode(_) => {
                return Err(Box::new(e));
            }
        },
        Ok(path) => path.to_owned(),
    };

    let log_file = File::create(filepath)?;

    WriteLogger::init(log_level_filter, config, log_file).unwrap();

    Ok(())
}

async fn start_program() -> Result<(), Box<dyn Error>> {
    info!("connecting to neovim via stdin/stdout");

    let (sender, receiver) = mpsc::channel();
    let mut session = Session::new_parent()?;
    session.start_event_loop_handler(NeovimHandler(sender));

    let mut nvim = Neovim::new(session);

    info!("let's notify neovim the plugin is connected!");
    nvim.command("echom \"twitch chat plugin connected to neovim\"")
        .unwrap();
    info!("notification complete!");

    nvim.subscribe("receive-message")
        .expect("error: cannot subscribe to event: insert-leave");
    nvim.subscribe("quit")
        .expect("error: cannot subscribe to event: quit");

    start_event_loop(receiver, nvim).await;

    Ok(())
}

fn channel_to_join() -> Result<String, Box<dyn std::error::Error>> {
    let channel = get_env_var("NVIM_TWITCH_CHANNEL")?;
    Ok(channel)
}

fn get_env_var(key: &str) -> Result<String, Box<dyn std::error::Error>> {
    let my_var = std::env::var(key)?;
    Ok(my_var)
}

async fn start_event_loop(receiver: mpsc::Receiver<Event>, nvim: Neovim) {
    dotenv::dotenv().ok();
    let twitch_name = get_env_var("NVIM_TWITCH_NAME").unwrap();
    let twitch_token = get_env_var("NVIM_TWITCH_TOKEN")
        .unwrap()
        .replacen("oauth:", "", 1);
    let channel_to_join = channel_to_join().unwrap();

    // default configuration is to join chat as anonymous.
    let config = ClientConfig {
        login_credentials: StaticLoginCredentials {
            credentials: CredentialsPair {
                login: twitch_name.clone(),
                token: Some(twitch_token),
            },
        },
        ..ClientConfig::default()
    };

    let (mut incoming_messages, client) =
        TwitchIRCClient::<TCPTransport, StaticLoginCredentials>::new(config);

    let nvim = Arc::new(Mutex::new(nvim));
    let nvim2 = nvim.clone();

    // first thing you should do: start consuming incoming messages,
    // otherwise they will back up.
    let join_handle = tokio::spawn(async move {
        let mut names = Vec::new();
        while let Some(message) = incoming_messages.recv().await {
            match message {
                ServerMessage::Privmsg(msg) => {
                    if !names.contains(&msg.sender.name) {
                        names.push(msg.sender.name.clone());

                        // update autocomplete list in vim
                        let mut nvim = nvim2.lock().unwrap();
                        nvim.call_function(
                            "twitchChat#setAutoComplete",
                            vec![msg.sender.name.as_str().into()],
                        )
                        .unwrap();
                    }
                }
                _ => (),
            }
        }
    });

    // join a channel
    client.join(channel_to_join.clone());

    loop {
        match receiver.recv() {
            Ok(Event::ReceivedMessage(msg)) => {
                let _ = client.say(twitch_name.clone(), msg).await.unwrap();
            }
            Ok(Event::Quit) => break,
            _ => {}
        }
    }

    join_handle.abort();

    info!("quitting");
    nvim.lock()
        .unwrap()
        .command("echom \"rust client disconnected from neovim\"")
        .unwrap();
}
