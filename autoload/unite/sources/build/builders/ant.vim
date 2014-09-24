"=============================================================================
" FILE: ant.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

" Variables  "{{{
call unite#util#set_default('g:unite_builder_ant_command', 'ant')
"}}}

function! unite#sources#build#builders#ant#define() "{{{
  return executable(unite#util#expand(g:unite_builder_ant_command)) ?
        \ s:builder : []
endfunction "}}}

let s:builder = {
      \ 'name': 'ant',
      \ 'description': 'ant builder',
      \ }

function! s:builder.detect(args, context) "{{{
  return filereadable('build.xml')
endfunction"}}}

function! s:builder.initialize(args, context) "{{{
  let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(getcwd())
  return g:unite_builder_ant_command . ' ' . join(a:args)
endfunction"}}}

function! s:builder.parse(string, context) "{{{
  if a:string =~ '^\s*$'
    " Skip.
    return {}
  elseif a:string =~ '\[.*\]\s\+\f\+:\d\+'
    " Error or warning.
    return s:analyze_error(matchstr(a:string,
          \ '\[.*\]\s\+\zs\f\+:\d\+.*'), a:context.builder__current_dir)
  endif

  return { 'type' : 'message', 'text' : a:string }
endfunction "}}}

function! s:analyze_error(string, current_dir) "{{{
  let string = a:string

  let [word, list] = [string, split(string[2:], ':')]
  let candidate = {}

  if empty(list)
    " Message.
    return { 'type' : 'message', 'text' : string }
  endif

  if len(word) == 1 && unite#util#is_windows()
    let candidate.word = word . list[0]
    let list = list[1:]
  endif

  let filename = unite#util#substitute_path_separator(word[:1].list[0])
  let candidate.filename = (filename !~ '^/\|\a\+:/') ?
        \ a:current_dir . '/' . filename : filename

  let list = list[1:]

  if !filereadable(filename) && '\<\f\+:'
    " Message.
    return { 'type' : 'message', 'text' : string }
  endif

  if len(list) > 0 && list[0] =~ '^\d\+$'
    let candidate.line = list[0]
    if len(list) > 1 && list[1] =~ '^\d\+$'
      let candidate.col = list[1]
      let list = list[1:]
    endif

    let list = list[1:]
  endif

  if len(list) > 1 && list[0] =~ '\s*\a\+'
    let candidate.type = tolower(matchstr(list[0], '\s*\zs\a\+'))
    if candidate.type != 'error' && candidate.type != 'warning'
      let candidate.type = 'message'
    endif
    let list = list[1:]
  else
    let candidate.type = 'message'
  endif

  let candidate.text = fnamemodify(filename, ':t') . ' : ' . join(list, ':')

  return candidate
endfunction"}}}

" vim: foldmethod=marker
