# Neovim Twitch Chat

This plugin let's you send text to twitch chat from inside neovim!

## Prerequesites

- cargo

## Setup twitch authentication

You will need to set the following environment variables
- NVIM_TWITCH_TOKEN can be generated at [twitchapps.com/tmi](https://twitchapps.com/tmi).
- NVIM_TWITCH_NAME is your twitch name
- NVIM_TWITCH_CHANNEL the twitch channel to join

## Install the binary

```bash
cargo install --force neovim-twitch-chat
```

## Install the plugin with plug

```vim
" If you have cargo installed, you can use the install script
" to automatically update the binary
Plug 'hardliner66/neovim-twitch-chat', { 'do': './install.sh' }

" If you manually installed the backend, you can just do
Plug 'hardliner66/neovim-twitch-chat'
```

## Default Bindings

```vim
vnoremap <silent> <C-s>v :<C-U>TwitchChatSendSelected<CR>
nnoremap <silent> <C-s>n :TwitchChatSendLine<CR>
nnoremap <silent> <C-s>k :TwitchChatScratch<CR>
```

## Settings
```vim
" scratch window height in percent
let g:twitch_scratch_height = 0.2

" if the scratch window shows on top or at the bottom
let g:twitch_scratch_top = 1

" if set to 1, automatically closes the scratch window on ESC
" and sends the whole buffer to twitch
"
" you can use <C-c> to enter normal mode even if twitch_scratch_autosend is set to 1
let g:twitch_scratch_autosend = 0

" list of usernames which get excluded for autocomplete
let g:twitch_chat_name_filter = ["username"]
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

