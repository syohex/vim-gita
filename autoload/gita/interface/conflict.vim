"******************************************************************************
" vim-gita interface/conflict
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:C = gita#util#import('VCS.Git.Conflict')

function! s:get_gita(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.interface = get(gita, 'interface', {})
  let gita.interface.diff = get(gita.interface, 'diff', {})
  return gita
endfunction " }}}
function! s:get_is_bufhidden(expr) abort " {{{
  let bufhidden = getbufvar(a:expr, '&bufhidden')
  return bufhidden == 'hidden' || &hidden
endfunction " }}}
function! s:smart_redraw() abort " {{{
  if &diff
    diffupdate | redraw!
  else
    redraw!
  endif
endfunction " }}}

function! s:2way_open(status, ...) abort " {{{
  let status  = a:status
  let path    = get(status, 'path2', status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'tabnew',
        \ 'vertical': 1,
        \}, get(a:000, 0, {}))

  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  " ORIGINAL
  call gita#util#buffer_open(path, options.opener)
  let ORIG_bufnum = bufnr('%')
  let ORIG_bufname = bufname('%')
  let filetype = &filetype
  let ORIG = getline(1, '$')

  " LOCAL
  let LOCAL_bufname = ORIG_bufname . '.LOCAL'
  silent execute 'enew ' . LOCAL_bufname
  silent execute 'setlocal filetype=' . filetype
  let LOCAL_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write(expand('<amatch>'))
    autocmd QuitPre <buffer> call s:ac_quit_pre()
  augroup END
  let LOCAL = s:C.strip_theirs(ORIG)
  call gita#util#buffer_update(LOCAL)
  diffthis

  " REMOTE
  let REMOTE_bufname = ORIG_bufname . '.REMOTE'
  silent execute printf('%s botright new %s', options.vertical ? 'vert' : '', REMOTE_bufname)
  silent execute 'setlocal filetype=' . filetype
  setlocal buftype=nofile bufhidden=wipe noswapfile
  let REMOTE_bufnum = bufnr('%')
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre <buffer> call s:ac_quit_pre()
  augroup END
  let REMOTE = s:C.get_ours(a:status.path)
  setlocal modifiable
  call gita#util#buffer_update(REMOTE)
  setlocal nomodifiable
  diffthis

  call setbufvar(LOCAL_bufnum, '_ORIG_bufnum', ORIG_bufnum)
  call setbufvar(LOCAL_bufnum, '_ORIG_bufname', ORIG_bufname)
  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)

  silent execute 'wincmd ='
  silent execute bufwinnr(LOCAL_bufnum) 'wincmd w'
endfunction " }}}
function! s:3way_open(status, ...) abort " {{{
  let status  = a:status
  let path    = get(status, 'path2', status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'tabnew',
        \ 'vertical': 1,
        \}, get(a:000, 0, {}))

  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  " ORIGINAL
  call gita#util#buffer_open(path, options.opener)
  let ORIG_bufnum = bufnr('%')
  let ORIG_bufname = bufname('%')
  let filetype = &filetype
  let ORIG = getline(1, '$')

  " MERGE
  let MERGE_bufname = ORIG_bufname . '.MERGE'
  silent execute 'enew ' . MERGE_bufname
  silent execute 'setlocal filetype=' . filetype
  let MERGE_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  silent execute printf('nnoremap <buffer><silent> dol :<C-u>diffget %s.LOCAL<CR>', ORIG_bufname)
  silent execute printf('nnoremap <buffer><silent> dor :<C-u>diffget %s.REMOTE<CR>', ORIG_bufname)
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write(expand('<amatch>'))
    autocmd QuitPre <buffer> call s:ac_quit_pre()
  augroup END
  let MERGE = s:C.strip_conflict(ORIG)
  call gita#util#buffer_update(MERGE)
  diffthis


  " LOCAL
  let LOCAL_bufname = ORIG_bufname . '.LOCAL'
  silent execute printf('%s topleft new %s', options.vertical ? 'vert' : '', LOCAL_bufname)
  silent execute 'setlocal filetype=' . filetype
  setlocal buftype=nofile bufhidden=wipe noswapfile
  let LOCAL_bufnum = bufnr('%')
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  silent execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s.MERGE<CR>', bufname)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre <buffer> call s:ac_quit_pre()
  augroup END
  let LOCAL = s:C.get_ours(a:status.path)
  setlocal modifiable
  call gita#util#buffer_update(LOCAL)
  setlocal nomodifiable
  diffthis

  " REMOTE
  let REMOTE_bufname = ORIG_bufname . '.REMOTE'
  silent execute printf('%s botright new %s', options.vertical ? 'vert' : '', REMOTE_bufname)
  silent execute 'setlocal filetype=' . filetype
  setlocal buftype=nofile bufhidden=wipe noswapfile
  let REMOTE_bufnum = bufnr('%')
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  silent execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s.MERGE<CR>', bufname)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre <buffer> call s:ac_quit_pre()
  augroup END
  let REMOTE = s:C.get_ours(a:status.path)
  setlocal modifiable
  call gita#util#buffer_update(REMOTE)
  setlocal nomodifiable
  diffthis

  call setbufvar(MERGE_bufnum, '_ORIG_bufnum', ORIG_bufnum)
  call setbufvar(MERGE_bufnum, '_ORIG_bufname', ORIG_bufname)
  call setbufvar(MERGE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(MERGE_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(LOCAL_bufnum, '_MERGE_bufnum', MERGE_bufnum)
  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(REMOTE_bufnum, '_MERGE_bufnum', MERGE_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)

  silent execute 'wincmd ='
  silent execute bufwinnr(MERGE_bufnum) 'wincmd w'
endfunction " }}}
function! s:ac_write() abort " {{{
  let filename = fnamemodify(expand(b:_ORIG_bufname), ':p')
  if a:filename != filename
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  if writefile(getline(1, '$'), filename) == 0
    setlocal nomodified
  endif
endfunction " }}}
function! s:ac_quit_pre() abort " {{{
  let mybufnum = bufnr('%')
  let bufnums = [
        \ get(b:, '_MERGE_bufnum', -1),
        \ get(b:, '_LOCAL_bufnum', -1),
        \ get(b:, '_REMOTE_bufnum', -1),
        \]
  for bufnum in bufnums
    if bufexists(bufnum) && bufnum != mybufnum
      let winnum = bufwinnr(bufnum)
      silent execute winnum 'wincmd w'
      silent diffoff
      augroup vim-gita-conflict
        autocmd! * <buffer>
      augroup END
      if s:get_is_bufhidden(bufnum) || !getbufvar(bufnum, '&modified', 0)
        silent execute printf('noautocmd %dquit', winnum)
      endif
    endif
  endfor
  silent execute bufwinnr(mybufnum) 'wincmd w'
  silent diffoff
  augroup vim-gita-conflict
    autocmd! * <buffer>
  augroup END
endfunction " }}}

function! gita#interface#conflict#2way_open(status, ...) abort " {{{
  call call('s:2way_open', extend([a:status], a:000))
endfunction " }}}
function! gita#interface#conflict#3way_open(status, ...) abort " {{{
  call call('s:3way_open', extend([a:status], a:000))
endfunction " }}}
function! gita#interface#conflict#smart_redraw() abort " {{{
  call call('s:smart_redraw')
endfunction " }}}

" Configure " {{{
let s:default = {}
let s:default.define_smart_redraw = 1

function! s:config() abort
  for [key, value] in items(s:default)
    let g:gita#interface#diff#{key} = get(g:, 'gita#interface#diff#' . key, value)
  endfor
endfunction
call s:config()
" }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker


