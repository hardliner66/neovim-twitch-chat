
if exists('g:twitch_chat_autoloaded_twitch_chat')
  finish
endif
let g:twitch_chat_autoloaded_twitch_chat = 1

if ! exists('s:jobid')
  let s:jobid = 0
endif

if ! exists('s:autocomplete_names')
    let s:autocomplete_names = []
endif

if ! exists('g:twitch_chat_name_filter')
    let g:twitch_chat_name_filter = []
endif

func! AutoCompleteNames()
  call complete(col('.'), s:autocomplete_names)
  return ''
endfunc

function! twitchChat#autoComplete(findstart, base)
    if a:findstart
        " locate the start of the word
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && (line[start - 1] != ' ') && (line[start - 1] =~ '\a' || line[start - 1] =~ '.' || line[start - 1] =~ '-')
            let start -= 1
        endwhile
        return start
    else
        " find classes matching "a:base"
        let res = []
        for m in s:autocomplete_names
            if index(g:twitch_chat_name_filter, m) > -1
                continue
            endif
            if m =~ '^' . a:base
                call add(res, m)
            endif
        endfor
        return res
    endif
endfun

let s:scriptdir = resolve(expand('<sfile>:p:h') . '/..')

if ! exists('g:twitch_chat_binary')
    let g:twitch_chat_binary = s:scriptdir . '/target/release/neovim-twitch-chat'
    if ! executable(g:twitch_chat_binary)
        let g:twitch_chat_binary = 'neovim-twitch-chat'
    endif
endif

function! twitchChat#setAutoComplete(...)
    let s:autocomplete_names = s:autocomplete_names + a:000
endfunction

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

function! Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:close_window(force)
    let content = Strip(join(getline(1,'$'), " "))
    if len(content) > 0
        call twitchChat#sendMessage(content)
    endif

  if a:force
    let prev_bufnr = bufnr('#')
    let scr_bufnr = bufnr('__Scratch__')
    if scr_bufnr != -1
      " Temporarily deactivate these autocommands to prevent overflow, but
      " still allow other autocommands to be executed.
      call s:deactivate_autocmds()
      close
      execute bufwinnr(prev_bufnr) . 'wincmd w'
      call s:activate_autocmds(scr_bufnr)
    endif
  elseif winbufnr(2) == -1
    if tabpagenr('$') == 1
      bdelete
      quit
    else
      close
    endif
  endif
endfunction

function! s:activate_autocmds(bufnr)
    augroup ScratchAutoHide
      autocmd!
      execute 'autocmd WinEnter <buffer=' . a:bufnr . '> nested call <SID>close_window(0)'
      execute 'autocmd Winleave <buffer=' . a:bufnr . '> nested call <SID>close_window(1)'
    augroup END
endfunction

function! s:deactivate_autocmds()
  augroup ScratchAutoHide
    autocmd!
  augroup END
endfunction

function! s:resolve_size(size)
  " if a:size is an int, return that number, else it is a float
  " interpret it as a fraction of the screen size and return the
  " corresponding number of lines
  if has('float') && type(a:size) ==# 5 " type number for float
    let win_size = winheight(0)
    return float2nr(a:size * win_size)
  else
    return a:size
  endif
endfunction

function! s:open_window(position)
  " open scratch buffer window and move to it. this will create the buffer if
  " necessary.
  let scr_bufnr = bufnr('__Scratch__')
  if scr_bufnr == -1
    let cmd = 'new'
    execute a:position . s:resolve_size(g:twitch_scratch_height) . cmd . ' __Scratch__'
    execute 'setlocal filetype=scratch'
    setlocal bufhidden=hide
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal foldcolumn=0
    setlocal nofoldenable
    setlocal nonumber
    setlocal noswapfile
    setlocal winfixheight
    setlocal winfixwidth
    setlocal completefunc=twitchChat#autoComplete
    inoremap <buffer><silent> <c-space> <C-x><C-u>
    call s:activate_autocmds(bufnr('%'))
  else
    let scr_winnr = bufwinnr(scr_bufnr)
    if scr_winnr != -1
      if winnr() != scr_winnr
        execute scr_winnr . 'wincmd w'
      endif
    else
      let cmd = 'split'
      execute a:position . s:resolve_size(g:twitch_scratch_height) . cmd . ' +buffer' . scr_bufnr
    endif
  endif
endfunction

function! twitchChat#scratchOpen()
  " sanity check and open scratch buffer
  if bufname('%') ==# '[Command Line]'
    echoerr 'Unable to open scratch buffer from command line window.'
    return
  endif
  let position = g:twitch_scratch_top ? 'topleft ' : 'botright '
  call s:open_window(position)
  silent execute '%d _'
endfunction

function! twitchChat#scratch()
  " open scratch buffer
  call twitchChat#scratchOpen()
  if g:twitch_scratch_autosend
    augroup ScratchInsertAutoHide
      autocmd!
      autocmd InsertLeave <buffer> nested call <SID>quick_insert()
    augroup END
  endif
  startinsert!
endfunction

function! s:quick_insert()
  " leave scratch window after leaving insert mode and remove corresponding autocommand
  augroup ScratchInsertAutoHide
    autocmd!
  augroup END
  execute bufwinnr(bufnr('#')) . 'wincmd w'
endfunction

