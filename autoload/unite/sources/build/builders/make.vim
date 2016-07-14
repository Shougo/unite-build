"=============================================================================
" FILE: make.vim
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
call unite#util#set_default('g:unite_builder_make_command', 'make')
"}}}

function! unite#sources#build#builders#make#define() "{{{
  return executable(unite#util#expand(g:unite_builder_make_command)) ?
        \ s:builder : []
endfunction "}}}

let s:builder = {
      \ 'name': 'make',
      \ 'description': 'make builder',
      \ }

function! s:builder.detect(args, context) "{{{
  return filereadable('Makefile') || filereadable('makefile')
endfunction"}}}

function! s:builder.initialize(args, context) "{{{
  let a:context.builder__dir_stack = []
  let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(getcwd())
  return g:unite_builder_make_command . ' ' . join(a:args)
endfunction"}}}

function! s:builder.parse(string, context) "{{{
  if a:string =~
        \'\<\f\+\%(\[\d\+\]\)\?\s*:\s*Entering\s\+directory\s\+`\f\+'''
    " Push current directory.
    call insert(a:context.builder__dir_stack, a:context.builder__current_dir)
    let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(matchstr(a:string, '`\zs\f\+\ze'''))
    return {}
  elseif a:string =~ '\<Making\%(\s\+\f\+\)\?\s\+in\s\+\f\+'
    " Push current directory.
    call insert(a:context.builder__dir_stack, a:context.builder__current_dir)
    let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(
        \ matchstr(a:string, '\<in\s\+\zs\f\+\ze'))
    return {}
  elseif a:string =~
        \'\<\f\+\%(\[\d\+\]\)\?\s*:\s*Leaving\s\+directory\s\+`\f\+'''
        \ && !empty(a:context.builder__dir_stack)
    " Pop current directory.
    let a:context.builder__current_dir = a:context.builder__dir_stack[0]
    let a:context.builder__dir_stack = a:context.builder__dir_stack[1:]
    return {}
  endif

  if a:string =~ ':' && a:string !~?
        \ ' Nothing to be done for `\f\+''\|' .
        \ ' is up to date.\|\s\+from \f\+\s*:\s*\d\+[:,]\|In file included from\|' .
        \ ' (Each undeclared identifier is reported only once,\|' .
        \ ' for each function it appears in.'
    " Error or warning.
    return s:analyze_error(a:string, a:context.builder__current_dir,
          \ a:context.source__builder_is_bang)
  endif

  return a:context.source__builder_is_bang ?
        \ { 'type' : 'message', 'text' : a:string } : {}
endfunction "}}}

function! s:analyze_error(string, current_dir, is_bang) "{{{
  let string = a:string
  if !a:is_bang && stridx(string, '<') >= 0
    " Snip nested template.
    let string = s:snip_nest(string, '<', '>', 1)
  endif

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

  if !filereadable(filename)
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

" s:snip_nest('std::vector<std::vector<int>>', '<', '>', 1)
"  => "std::vector<std::vector<>>"
function! s:snip_nest(str, start, end, max) "{{{
  let _ = ''
  let nest_level = 0
  for c in split(a:str, '\zs')
    if c ==# a:start
      let nest_level += 1
      let _ .= c
    elseif c ==# a:end
      let nest_level -= 1
      let _ .= c
    elseif nest_level <= a:max
      let _ .= c
    endif
  endfor

  return _
endfunction"}}}

" vim: foldmethod=marker
