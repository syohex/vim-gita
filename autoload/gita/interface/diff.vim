"******************************************************************************
" vim-gita interface/diff
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:get_sid() " {{{
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_get_sid$')
endfun " }}}
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
    let mname = printf(':<C-u>call %ssmart_redraw<CR>', s:get_sid())
    if maparg('<C-l>', 'n') == mname
      silent execute 'nunmap <buffer> <C-l>'
    endif
    redraw!
  endif
endfunction " }}}

function! s:open(status, commit, ...) abort " {{{
  let status  = a:status
  let path    = get(status, 'path2', status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'edit',
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'R': 1,
        \ 'histogram': 1,
        \}, get(a:000, 0, {}))

  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  let result = gita.git.diff(options, a:commit, path)
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif
  
  " open diff
  silent execute options.opener 'new'
  silent execute printf('file %s.%s.diff', path, a:commit)
  silent execute 'filetype detect'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted

  setlocal modifiable
  call gita#util#buffer_update(split(result.stdout, '\v\r?\n'))
  setlocal nomodifiable
endfunction " }}}
function! s:compare(status, commit, ...) abort " {{{
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

  let args = ['show', printf('%s:%s', a:commit, a:status.path)]
  let result = gita.git.exec(args)
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif

  " LOCAL
  call gita#util#buffer_open(path, options.opener)
  let LOCAL_bufnum = bufnr('%')
  let LOCAL_bufname = bufname('%')
  let filetype = &filetype
  nnoremap <buffer> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre <buffer> call s:diff_ac_quit_pre()
  augroup END
  diffthis

  " REMOTE
  let REMOTE_bufname = printf('%s.%s', LOCAL_bufname, a:commit)
  let opener = options.vertical ? 'vert new' : 'new'
  silent execute printf('%s %s', opener, REMOTE_bufname)
  let REMOTE_bufnum = bufnr('%')
  silent execute printf('file %s', REMOTE_bufname)
  silent execute printf('setlocal filetype=%s', filetype)
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  nnoremap <buffer> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre <buffer> call s:diff_ac_quit_pre()
  augroup END

  setlocal modifiable
  call gita#util#buffer_update(split(result.stdout, '\v\r?\n'))
  setlocal nomodifiable
  diffthis

  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)

  silent execute 'wincmd ='
  silent execute bufwinnr(LOCAL_bufnum) 'wincmd w'
endfunction " }}}
function! s:diff_ac_quit_pre() abort " {{{
  let mybufnum = bufnr('%')
  let bufnums = [
        \ get(b:, '_LOCAL_bufnum', -1),
        \ get(b:, '_REMOTE_bufnum', -1),
        \]
  for bufnum in bufnums
    if bufexists(bufnum) && bufnum != mybufnum
      let winnum = bufwinnr(bufnum)
      silent execute winnum 'wincmd w'
      silent diffoff
      augroup vim-gita-diff
        autocmd! * <buffer>
      augroup END
      if s:get_is_bufhidden(bufnum) || !getbufvar(bufnum, '&modified', 0)
        silent execute printf('noautocmd %dquit', winnum)
      endif
    endif
  endfor
  silent execute bufwinnr(mybufnum) 'wincmd w'
  silent diffoff
  augroup vim-gita-diff
    autocmd! * <buffer>
  augroup END
endfunction " }}}

function! gita#interface#diff#open(status, commit, ...) abort " {{{
  call call('s:open', extend([a:status, a:commit], a:000))
endfunction " }}}
function! gita#interface#diff#compare(status, commit, ...) abort " {{{
  call call('s:compare', extend([a:status, a:commit], a:000))
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

