"******************************************************************************
" vim-gita statusline
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
scriptencoding utf8

let s:save_cpo = &cpo
set cpo&vim

function! s:get_info(...) abort " {{{
  let gita = call('gita#get', a:000)
  if gita.enabled
    let meta = gita.git.get_meta()
    let info = {
          \ 'local_name': fnamemodify(gita.git.worktree, ':t'),
          \ 'local_branch': meta.current_branch,
          \ 'remote_name': meta.current_branch_remote,
          \ 'remote_branch': meta.current_remote_branch,
          \ 'outgoing': meta.commits_ahead_of_remote,
          \ 'incoming': meta.commits_behind_remote,
          \}
    let info = extend(info, s:get_statuses())
  else
    let info = {}
  endif
  return info
endfunction " }}}
function! s:get_statuses() abort " {{{
  let gita = gita#get()
  let options = extend(
        \ get(b:, '_options', {}),
        \ extend(
        \  get(g:, 'gita#interface#status#default_options', {}),
        \  get(a:000, 0, {})
        \ )
        \)
  if gita.enabled
    let statuses = gita.git.get_parsed_status(options)
    if get(statuses, 'status', 0) != 0
      call gita#util#debug(statuses.stdout)
      return {
            \ 'conflicted': 0,
            \ 'unstaged': 0,
            \ 'added': 0,
            \ 'deleted': 0,
            \ 'renamed': 0,
            \ 'modified': 0,
            \}
    endif
    " Note:
    "   the 'statuses' is cached, mean that 'untracked' doesn't reflect the
    "   real. That's why 'untracked' is missing in the following dictionary.
    let status_counts = {
          \ 'conflicted': len(statuses.conflicted),
          \ 'unstaged': len(statuses.unstaged),
          \ 'staged': len(statuses.staged),
          \ 'added': 0,
          \ 'deleted': 0,
          \ 'renamed': 0,
          \ 'modified': 0,
          \}
    for status in statuses.staged
      if status.index ==# 'A'
        let status_counts.added += 1
      elseif status.index ==# 'D'
        let status_counts.deleted += 1
      elseif status.index ==# 'R'
        let status_counts.renamed += 1
      else
        let status_counts.modified += 1
      endif
    endfor
    return status_counts
  else
    return {}
  endif
endfunction " }}}
function! s:format(format, info) abort " {{{
  return gita#util#format(a:format, s:format_map, a:info)
endfunction
let s:format_map = {
      \ 'ln': 'local_name',
      \ 'lb': 'local_branch',
      \ 'rn': 'remote_name',
      \ 'rb': 'remote_branch',
      \ 'ic': 'incoming',
      \ 'og': 'outgoing',
      \ 'nc': 'conflicted',
      \ 'nu': 'unstaged',
      \ 'ns': 'staged',
      \ 'na': 'added',
      \ 'nd': 'deleted',
      \ 'nr': 'renamed',
      \ 'nm': 'modified',
      \}
" }}}
function! s:clear() abort " {{{
  let gita = gita#get()
  if gita.enabled
    call gita.git.cache.repository.clear()
  endif
endfunction " }}}

function! gita#statusline#info(...) " {{{
  return call('s:get_info', a:000)
endfunction " }}}
function! gita#statusline#format(format, ...) " {{{
  let info = get(a:000, 0, s:get_info())
  return s:format(a:format, info)
endfunction " }}}
function! gita#statusline#preset(name, ...) " {{{
  let info = get(a:000, 0, s:get_info())
  let format = get(s:preset, a:name, '')
  if strlen(format) == 0
    return ''
  endif
  return s:format(format, info)
endfunction
let s:preset = {
      \ 'branch': '%{|/}ln%lb%{ <> |}rn%{/|}rb',
      \ 'branch_fancy': '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb',
      \ 'status': '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu',
      \ 'traffic': '%{<| }ic%{>|}og',
      \ 'traffic_fancy': '%{￩| }ic%{￫}og',
      \}
" }}}
function! gita#statusline#clear(...) " {{{
  call s:clear()
endfunction " }}}

augroup vim-gita-statusline
  autocmd! *
  " several git command does not update .git/index thus use hooks to clear
  " statusline cache
  autocmd User vim-gita-commit-post call gita#statusline#clear()
  autocmd User vim-gita-fetch-post  call gita#statusline#clear()
  autocmd User vim-gita-push-post   call gita#statusline#clear()
  autocmd User vim-gita-pull-post   call gita#statusline#clear()
  autocmd User vim-gita-submodule-post call gita#statusline#clear()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
