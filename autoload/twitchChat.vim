
if exists('g:autoloaded_twitch_chat')
  finish
endif
let g:autoloaded_twitch_chat = 1

if ! exists('s:jobid')
  let s:jobid = 0
endif

let s:scriptdir = resolve(expand('<sfile>:p:h') . '/..')

if ! exists('g:twitch_chat_binary')
    let g:twitch_chat_binary = s:scriptdir . '/target/release/neovim-twitch-chat'
    if ! executable(g:twitch_chat_binary)
        let g:twitch_chat_binary = 'neovim-twitch-chat'
    endif
endif

function! twitchChat#init()
  call twitchChat#connect()
endfunction

function! twitchChat#connect()
  let result = s:StartJob()

  if 0 == result
    echoerr "twitch chat: cannot start rpc process"
  elseif -1 == result
    echoerr "twitch chat: rpc process is not executable"
  else
    let s:jobid = result
    call s:ConfigureJob(result)
  endif
endfunction

function! twitchChat#sendMessage(msg)
    call rpcnotify(s:jobid, 'received-message', substitute(a:msg, '(\r\n|\r|\n)', ' ', 'g'))
endfunction

function! twitchChat#sendSelected()
    let selected = VisualSelection()
    call twitchChat#sendMessage(l:selected)
endfunction

function! VisualSelection()
    if mode()=="v"
        let [line_start, column_start] = getpos("v")[1:2]
        let [line_end, column_end] = getpos(".")[1:2]
    else
        let [line_start, column_start] = getpos("'<")[1:2]
        let [line_end, column_end] = getpos("'>")[1:2]
    end

    if (line2byte(line_start)+column_start) > (line2byte(line_end)+column_end)
        let [line_start, column_start, line_end, column_end] =
        \   [line_end, column_end, line_start, column_start]
    end
    let lines = getline(line_start, line_end)
    if len(lines) == 0
            return ['']
    endif
    if &selection ==# "exclusive"
        let column_end -= 1 "Needed to remove the last character to make it match the visual selction
    endif
    if visualmode() ==# "\<C-V>"
        for idx in range(len(lines))
            let lines[idx] = lines[idx][: column_end - 1]
            let lines[idx] = lines[idx][column_start - 1:]
        endfor
    else
        let lines[-1] = lines[-1][: column_end - 1]
        let lines[ 0] = lines[ 0][column_start - 1:]
    endif
    return join(lines, " ") "use this return instead if you need a text block
endfunction

function! twitchChat#sendLine()
    let selected = getline(".")
    call twitchChat#sendMessage(l:selected)
endfunction

function! twitchChat#reset()
  let s:jobid = 0
endfunction

function! s:ConfigureJob(jobid)
  augroup twitchChat
    " clear all previous autocommands
    autocmd!

  augroup END
endfunction

function! s:OnStderr(id, data, event) dict
  echom 'twitch chat: stderr: ' . join(a:data, " ")

  " let text = 'twitch chat: stderr: ' . join(a:data, "\n")
  " exe "normal! a" . text . "\<Esc>"
endfunction

function! s:StartJob()
  if 0 == s:jobid
    let id = jobstart([g:twitch_chat_binary], { 'rpc': v:true, 'on_stderr': function('s:OnStderr'), "env": {'CWD': getcwd()} })
    return id
  else
    return 0
  endif
endfunction

function! s:StopJob()
  if 0 < s:jobid
    augroup twitchChat
      autocmd!    " clear all previous autocommands
    augroup END

    call rpcnotify(s:jobid, 'quit')
    let result = jobwait(s:jobid, 500)

    if -1 == result
      " kill the job
      call jobstop(s:jobid)
    endif

    " reset job id back to zero
    let s:jobid = 0
  endif
endfunction

call twitchChat#connect()
