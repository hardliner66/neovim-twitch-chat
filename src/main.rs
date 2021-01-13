mod args;
mod event;
mod handler;

use twitch_chat_wrapper::{run, ChatMessage};
use std::sync::mpsc::channel;
use crate::event::Event;
use crate::handler::NeovimHandler;

use log::*;

use neovim_lib::neovim::Neovim;
use neovim_lib::neovim_api::NeovimApi;
use neovim_lib::session::Session;

use simplelog::{Config, LogLevel, LogLevelFilter, WriteLogger};

use std::error::Error;
use std::sync::mpsc;

fn main() {
    use std::process;

    init_logging().expect("twitch chat: unable to initialize logger.");

    match start_program() {
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
        .unwrap_or(String::from("trace"))
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

fn start_program() -> Result<(), Box<dyn Error>> {
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

    start_event_loop(receiver, nvim);

    Ok(())
}

fn channel_to_join() -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let channel = get_env_var("NVIM_TWITCH_CHANNEL")?;
    Ok(vec![channel])
}

fn get_env_var(key: &str) -> Result<String, Box<dyn std::error::Error>> {
    let my_var = std::env::var(key)?;
    Ok(my_var)
}

fn start_event_loop(receiver: mpsc::Receiver<Event>, mut nvim: Neovim) {
    dotenv::dotenv().ok();
    let (tx, rx) = channel::<String>();
    let (tx2, rx2) = channel::<ChatMessage>();

    let twitch_name = get_env_var("NVIM_TWITCH_NAME").unwrap();
    let twitch_token = get_env_var("NVIM_TWITCH_TOKEN").unwrap();
    let channel_to_join = channel_to_join().unwrap();

    std::thread::spawn(move || {
        run(twitch_name, twitch_token, channel_to_join, rx, tx2).unwrap()
    });

    std::thread::spawn(move || {
        loop {
            let _msg = rx2.recv();
            std::thread::sleep(std::time::Duration::from_secs(1));
        }
    });

    loop {
        match receiver.recv() {
            Ok(Event::ReceivedMessage(msg)) => {
                let _ = tx.send(msg);
            },
            Ok(Event::Quit) => break,
            _ => {}
        }
    }
    info!("quitting");
    nvim.command("echom \"rust client disconnected from neovim\"")
        .unwrap();
}

