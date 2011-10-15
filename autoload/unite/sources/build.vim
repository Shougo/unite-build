"=============================================================================
" FILE: build.vim
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

" Actions "{{{
" }}}

function! unite#sources#build#define() "{{{
  " Init builders.
  for name in map(split(globpath(&runtimepath,
        \ 'autoload/unite/sources/build/builders/*.vim'), '\n'),
        \ 'fnamemodify(v:val, ":t:r")')
    let define = {'unite#sources#build#builders#' . name . '#define'}()
    for dict in (type(define) == type([]) ? define : [define])
      if !empty(dict) && !has_key(s:builders, dict.name)
        let s:builders[dict.name] = dict
      endif
    endfor
    unlet define
  endfor

  return s:source
endfunction "}}}

let s:builders = {}
let s:source = {
      \ 'name': 'build',
      \ 'hooks' : {},
      \ 'syntax' : 'uniteSource__Build',
      \ }

function! s:source.hooks.on_init(args, context) "{{{
  let a:context.source__builder_name = get(a:args, 0, '')
  let a:context.source__builder_args = a:args[1:]

  if a:context.source__builder_name == ''
    " Detect builder.
    for builder in values(s:builders)
      if builder.detect(a:args, a:context)
        let a:context.source__builder_name = builder.name
        break
      endif
    endfor
  endif
endfunction"}}}
function! s:source.hooks.on_syntax(args, context)"{{{
  syntax match uniteSource__Builder_Error
        \ /\s*\[Error\s*] : .*/ contained containedin=uniteSource__Build
  syntax match uniteSource__Builder_Warning
        \ /\s*\[Warning\s*] : .*/ contained containedin=uniteSource__Build
  syntax match uniteSource__Builder_Message
        \ /\s*\[Message\s*] : .*/ contained containedin=uniteSource__Build
  highlight default link uniteSource__Builder_Error Error
  highlight default link uniteSource__Builder_Warning WarningMsg
  highlight default link uniteSource__Builder_Message Comment
endfunction"}}}
function! s:source.hooks.on_close(args, context) "{{{
  if has_key(a:context, 'source__proc')
    call a:context.source__proc.waitpid()
  endif
endfunction "}}}

function! s:source.gather_candidates(args, context) "{{{
  if empty(a:context.source__builder_name)
    let a:context.is_async = 0
    call unite#print_message('[build] empty builder.')
    return []
  endif

  if !unite#util#has_vimproc()
    call unite#print_message('[build] no vimproc is detected.')
    return []
  endif

  let a:context.source__builder =
        \ s:builders[a:context.source__builder_name]

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  let cmdline = a:context.source__builder.initialize(
        \ a:context.source__builder_args, a:context)
  call unite#print_message('[build] Command-line: ' . cmdline)
  let a:context.source__proc = vimproc#pgroup_open(cmdline, 0, 2)

  " Close handles.
  call a:context.source__proc.stdin.close()

  return []
endfunction "}}}

function! s:source.async_gather_candidates(args, context) "{{{
  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    call unite#print_message('[build] Completed.')
    let a:context.is_async = 0
  endif

  let candidates = []
   for string in map(stdout.read_lines(-1, 300),
        \ 'iconv(v:val, &termencoding, &encoding)')
     let candidate = a:context.source__builder.parse(string, a:context)
     if !empty(candidate)
       call s:init_candidate(candidate)
       call add(candidates, candidate)
     endif
   endfor

  call map(candidates,
    \ "{
    \   'word': printf('[%-7s] : %s',
    \       substitute(v:val.type, '^.', '\\u\\0', ''), v:val.text),
    \   'kind': (v:val.filename == '' ? 'common' : 'jump_list'),
    \   'action__path' : v:val.filename,
    \   'action__line' : v:val.line,
    \   'action__col' : v:val.col,
    \   'action__pattern' : v:val.pattern,
    \   'action__directory' :
    \       unite#util#path2directory(v:val.filename),
    \   'is_dummy' : (v:val.type ==# 'message'),
    \ }")

  return candidates
endfunction "}}}

function! s:init_candidate(candidate)
  if !has_key(a:candidate, 'filename')
    let a:candidate.filename = ''
  endif
  if !has_key(a:candidate, 'line')
    let a:candidate.line = 0
  endif
  if !has_key(a:candidate, 'col')
    let a:candidate.col = 0
  endif
  if !has_key(a:candidate, 'pattern')
    let a:candidate.pattern = ''
  endif
endfunction

" vim: foldmethod=marker
