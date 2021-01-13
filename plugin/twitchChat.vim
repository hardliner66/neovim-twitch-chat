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

if !exists('g:twitch_scratch_height')
  let g:twitch_scratch_height = 0.2
endif

if !exists('g:twitch_scratch_top')
  let g:twitch_scratch_top = 1
endif

command! -nargs=0 TwitchChatConnect call twitchChat#connect()
command! -nargs=0 TwitchChatSendSelected call twitchChat#sendSelected()
command! -nargs=0 TwitchChatSendLine call twitchChat#sendLine()
command! -nargs=1 TwitchChatSendMessage call twitchChat#sendMessage(<q-args>)
command! -nargs=0 TwitchChatScratch call twitchChat#scratch()

vnoremap <silent> <C-s>v :<C-U>TwitchChatSendSelected<CR>
nnoremap <silent> <C-s>n :TwitchChatSendLine<CR>
nnoremap <silent> <C-s>k :TwitchChatScratch<CR>
