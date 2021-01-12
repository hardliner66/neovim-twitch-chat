" File: twitchChat.vim
" Last Modified: 2021-01-12
" Version: 0.0.1
" Description: Twitch Chat -- allows sending of commands to twitch from inside vim.
" Website: 
" Author: Steve Biedermann
" License: MIT + Apache 2.0
"
" Copyright 2021 Steve Biedermann
"
" Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
" http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
" <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
" option. This file may not be copied, modified, or distributed
" except according to those terms.

command! -nargs=0 TwitchChatConnect call twitchChat#connect()
command! -nargs=0 TwitchChatSendSelected call twitchChat#sendSelected()
command! -nargs=0 TwitchChatSendLine call twitchChat#sendLine()
command! -nargs=1 TwitchChatSendMessage call twitchChat#sendMessage(<q-args>)

vnoremap <silent> <C-s>s :<C-U>TwitchChatSendSelected<CR>
nnoremap <silent> <C-s>l :TwitchChatSendLine<CR>
