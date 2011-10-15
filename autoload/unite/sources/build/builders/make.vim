"=============================================================================
" FILE: make.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 15 Oct 2011.
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
  return executable(g:unite_builder_make_command) ?
        \ s:builder : []
endfunction "}}}

let s:builder = {
      \ 'name': 'make',
      \ 'description': 'make builder',
      \ }

function! s:builder.detect(args, context) "{{{
  return filereadable('Makefile')
endfunction"}}}

function! s:builder.initialize(args, context) "{{{
  let a:context.builder__current_dir = getcwd()
  return g:unite_builder_make_command . ' ' . join(a:args)
endfunction"}}}

function! s:builder.parse(string, context) "{{{
  return { 'type' : 'message', 'text' : a:string }
endfunction "}}}

" vim: foldmethod=marker
