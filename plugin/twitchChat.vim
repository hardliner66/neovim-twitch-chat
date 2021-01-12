" File: twitchChat.vim
" Last Modified: 2021-01-12
" Version: 0.0.1
" Description: Twitch Chat -- allows sending of commands to twitch from inside vim.
" Website: 
" Author: Steve Biedermann
" License: MIT + Apache 2.0

if exists('g:loaded_twitch_chat')
  finish
endif
let g:loaded_twitch_chat = 1

command! -nargs=0 TwitchChatConnect call twitchChat#connect()
command! -nargs=0 TwitchChatSendSelected call twitchChat#sendSelected()
command! -nargs=0 TwitchChatSendLine call twitchChat#sendLine()
command! -nargs=1 TwitchChatSendMessage call twitchChat#sendMessage(<q-args>)

vnoremap <silent> <C-s>s :<C-U>TwitchChatSendSelected<CR>
nnoremap <silent> <C-s>l :TwitchChatSendLine<CR>
