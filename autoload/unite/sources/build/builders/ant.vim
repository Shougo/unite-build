"=============================================================================
" FILE: ant.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 25 Sep 2013.
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
  return executable(g:unite_builder_ant_command) ?
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
  let a:context.builder__dir_stack = []
  let a:context.builder__current_dir =
        \ unite#util#substitute_path_separator(getcwd())
  return g:unite_builder_ant_command . ' ' . join(a:args)
endfunction"}}}

function! s:builder.parse(string, context) "{{{
  return a:context.source__builder_is_bang ?
        \ { 'type' : 'message', 'text' : a:string } : {}
endfunction "}}}

" vim: foldmethod=marker
