"=============================================================================
" FILE: maven.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license  {{{
"     Permission is hereby grmavened, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substmavenial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRmavenY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRmavenIES OF
"     MERCHmavenABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

" Variables  "{{{
call unite#util#set_default('g:unite_builder_maven_command', 'mvn')
"}}}

function! unite#sources#build#builders#maven#define() "{{{
  return executable(unite#util#expand(g:unite_builder_maven_command)) ?
        \ s:builder : []
endfunction "}}}

let s:builder = {
      \ 'name': 'maven',
      \ 'description': 'maven builder',
      \ }

function! s:builder.detect(args, context) "{{{
  return filereadable('pom.xml')
endfunction"}}}

function! s:builder.initialize(args, context) "{{{
  let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(getcwd())
  return g:unite_builder_maven_command
        \ . ' ' . (empty(a:args) ? 'compile' : join(a:args))
endfunction"}}}

function! s:builder.parse(string, context) "{{{
  if a:string =~ '^\s*$'
    " Skip.
    return {}
  elseif a:string =~ '\[\u\+\]\s*$'
    " Skip.
    return {}
  elseif a:string =~ ' error: '
    " Error or warning.
    return s:analyze_error(a:string, a:context.builder__current_dir)
  endif

  return { 'type' : 'message', 'text' :
        \    substitute(a:string, '^\[\u\+\]\s\+', '', '') }
endfunction "}}}

function! s:analyze_error(string, current_dir) "{{{
  let matches = matchlist(a:string,
        \ '^\(\[\u\+\]\)\?\s\+\(\f\+\):\[\(\d\+\),\(\d\+\)\]\s\+\(.*\)$')
  let filename = unite#util#substitute_path_separator(matches[1])
  if filename !~ '^/\|\a\+:/'
    let filename = a:current_dir . '/' . filename
  endif

  return { 'type' : (a:string =~# ' error: ' ? 'error' : 'warning'),
        \ 'filename' : filename, 'line' : matches[2], 'col' : matches[3],
        \ 'text' : fnamemodify(filename, ':t') . ' : ' . matches[4] }
endfunction"}}}

" vim: foldmethod=marker
