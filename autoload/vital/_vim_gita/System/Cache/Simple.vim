"******************************************************************************
" A simple cache system which store cached values in instances
"
" Author:   Alisue <lambdalisue@cache_keynote.net>
" URL:      http://cache_keynote.net/
" License:  MIT license
" (C) 2014, Alisue, cache_keynote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort " {{{
  let s:Base = a:V.import('System.Cache.Base')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return ['System.Cache.Base']
endfunction " }}}

let s:cache = { '_cached': {} }
function! s:new() abort " {{{
  return extend(s:Base.new(), deepcopy(s:cache))
endfunction " }}}

function! s:cache.has(name) abort " {{{
  let cache_key = self.cache_key(a:name)
  return has_key(self._cached, cache_key)
endfunction " }}}
function! s:cache.get(name, ...) abort " {{{
  let default = get(a:000, 0, '')
  let cache_key = self.cache_key(a:name)
  if has_key(self._cached, cache_key)
    return self._cached[cache_key]
  else
    return default
  endif
endfunction " }}}
function! s:cache.set(name, value) abort " {{{
  let cache_key = self.cache_key(a:name)
  let self._cached[cache_key] = a:value
endfunction " }}}
function! s:cache.remove(name) abort " {{{
  let cache_key = self.cache_key(a:name)
  if has_key(self._cached, cache_key)
    unlet self._cached[cache_key]
  endif
endfunction " }}}
function! s:cache.keys() abort " {{{
  return keys(self._cached)
endfunction " }}}
function! s:cache.clear() abort " {{{
  let self._cached = {}
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
