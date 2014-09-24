"=============================================================================
" FILE: repoman.vim
" AUTHOR:  Tatsuhiro Ujihisa <ujihisa at gmail.com>
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
call unite#util#set_default('g:unite_builder_repoman_command', 'repoman')
"}}}

function! unite#sources#build#builders#repoman#define() "{{{
  return executable(unite#util#expand(g:unite_builder_repoman_command)) ?
        \ s:builder : []
endfunction "}}}

let s:builder = {
      \ 'name': 'repoman',
      \ 'description': 'repoman builder for ebuild files',
      \ }

function! s:builder.detect(args, context) "{{{
  return !empty(split(glob('*.ebuild'), "\n"))
endfunction"}}}

function! s:builder.initialize(args, context) "{{{
  let a:context.__state = ''
  let arg = empty(a:args) ? 'manifest' : join(a:args)
  return g:unite_builder_repoman_command . ' ' . arg
endfunction"}}}

function! s:builder.parse(string, context)
  if empty(a:string)
    return {}
  endif
  if a:context.source__builder_args[0] ==# 'manifest'
    return s:_parse_manifest(a:string, a:context)
  elseif a:context.source__builder_args[0] ==# 'full'
    return s:_parse_full(a:string, a:context)
  else
    return {'type': 'message', 'text': printf('# %s', a:string)}
  endif
endfunction

function! s:_parse_manifest(string, context)
  let matches = matchlist(a:string, ">>> \\(\\w\\+\\) \\(.*\\)$")
  "echomsg string([a:context.__state, matches])
  if len(matches) > 0 && matches[2] !=# ''
    let a:context.__state = matches[1]
    return {'type': 'message', 'text': printf('%s %s', matches[1], matches[2])}
  endif
  if a:context.__state ==# 'Downloading'
    if a:string =~ '^\s\+\|^Resolving\|^Connecting\|^HTTP request sent\|^==>\|^Location: '
      return a:context.source__builder_is_bang ?
            \ {'type': 'message', 'text': printf('  %s', a:string)} : {}
    endif
  endif
  return {'type': 'message', 'text': printf('  %s', a:string)}
endfunction

function! s:_parse_full(string, context)
  if a:string == 'RepoMan scours the neighborhood...'
    return {}
  endif
  return {'type': 'message', 'text': printf('* %s', a:string)}
endfunction

" vim: foldmethod=marker
