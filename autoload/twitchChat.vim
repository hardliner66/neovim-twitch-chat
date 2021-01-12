if ! exists('s:jobid')
  let s:jobid = 0
endif

let s:scriptdir = resolve(expand('<sfile>:p:h') . '/..')

if ! exists('g:twitch_chat_program')
  let g:twitch_chat_program = s:scriptdir . '/target/release/neovim-twitch-chat'
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
    call rpcnotify(s:jobid, 'received-message', a:msg)
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
  echom 'twitch chat: stderr: ' . join(a:data, "\n")
endfunction

function! s:StartJob()
  if 0 == s:jobid
    let id = jobstart([g:twitch_chat_program], { 'rpc': v:true, 'on_stderr': function('s:OnStderr') })
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
