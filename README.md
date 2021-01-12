# Neovim Twitch Chat

This plugin let's you send text to twitch chat from inside neovim!

## Prerequesites

- cargo

## Setup twitch authentication

You will need to set the following environment variables
- NEOVIM_TWITCH_TOKEN can be generated at [twitchapps.com/tmi](https://twitchapps.com/tmi).
- NEOVIM_TWITCH_NAME is your twitch name
- NEOVIM_TWITCH_CHANNEL the twitch channel to join

## Install the binary

```bash
git clone https://github.com/hardliner66/neovim-twitch-chat
cd neovim-twitch-chat
cargo install --force --path .
```

## Install the plugin with plug

```vim
Plug 'hardliner66/neovim-twitch-chat'
```

## Default Bindings

```vim
vnoremap <silent> <C-s>s :<C-U>TwitchChatSendSelected<CR>
nnoremap <silent> <C-s>l :TwitchChatSendLine<CR>
```

## Development Setup

1.  Install Rustup:  https://www.rustup.rs/

2.  Use the stable rust compiler.

```sh
rustup install stable
rustup default stable

```

2.  Fetch the plugin.

```sh
$ git clone https://github.com/hardliner66/neovim-twitch-chat
```

3.  Build the binary portion of the plugin.

```sh
$ cd neovim-twitch-chat
$ cargo build --release
```

4.  Test it out in a fresh instance of Neovim.

```sh
nvim -u ./init.vim --noplugin -c ":TwitchChatConnect"
```

The `TwitchChatConnect` command spawns the Rust plugin in a separate process and
establishes a channel.

