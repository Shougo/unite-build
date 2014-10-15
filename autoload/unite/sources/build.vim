"=============================================================================
" FILE: build.vim
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
call unite#util#set_default('g:unite_build_error_text', '!!')
call unite#util#set_default('g:unite_build_warning_text', '??')
call unite#util#set_default('g:unite_build_error_highlight', 'Error')
call unite#util#set_default('g:unite_build_warning_highlight', 'Todo')
call unite#util#set_default('g:unite_build_error_icon', '')
call unite#util#set_default('g:unite_build_warning_icon', '')
"}}}

" Actions "{{{
" }}}

function! unite#sources#build#define() "{{{
  if has('signs')
    " Init signs.
    let error_icon = filereadable(expand(g:unite_build_error_icon)) ?
          \ ' icon=' . escape(expand(g:unite_build_error_icon), '| \') : ''
    let warning_icon = filereadable(expand(g:unite_build_warning_icon)) ?
          \ ' icon=' . escape(expand(g:unite_build_warning_icon), '| \') : ''
    execute 'sign define unite_build_error text=' . g:unite_build_error_text .
          \ ' linehl=' . g:unite_build_error_highlight . error_icon
    execute 'sign define unite_build_warning text=' . g:unite_build_warning_text .
          \ ' linehl=' . g:unite_build_warning_highlight . warning_icon

    command! UniteBuildClearHighlight call s:clear_highlight()
  endif

  if empty(s:builders)
    call s:init_builders()
  endif

  return s:source
endfunction "}}}

function! unite#sources#build#get_builders_name() "{{{
  if empty(s:builders)
    call s:init_builders()
  endif

  return keys(s:builders)
endfunction "}}}

let s:init_id = 10000
let s:sign_id_dict = {}

let s:builders = {}
let s:source = {
      \ 'name': 'build',
      \ 'hooks' : {},
      \ 'syntax' : 'uniteSource__Build',
      \ }

function! s:source.hooks.on_init(args, context) "{{{
  let a:context.source__builder_is_bang = get(a:args, 0, '') == '!'
  let args = a:context.source__builder_is_bang ?
        \ a:args[1:] : a:args
  let a:context.source__builder_name = get(args, 0, '')
  let a:context.source__builder_args = args[1:]

  if a:context.source__builder_name == ''
    " Detect builder.
    for builder in values(s:builders)
      if has_key(builder, 'detect') && builder.detect(args, a:context)
        let a:context.source__builder_name = builder.name
        break
      endif
    endfor
  endif
endfunction"}}}
function! s:source.hooks.on_syntax(args, context) "{{{
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

function! s:source.complete(args, context, arglead, cmdline, cursorpos) "{{{
  return filter(unite#sources#build#get_builders_name(),
        \ 'stridx(v:val, a:arglead) == 0')
endfunction"}}}

function! s:source.gather_candidates(args, context) "{{{
  if empty(a:context.source__builder_name)
    let a:context.is_async = 0
    call unite#print_message('[build] empty builder.')
    return []
  elseif !has_key(s:builders, a:context.source__builder_name)
    let a:context.is_async = 0
    call unite#print_message('[build] builder "' .
          \ a:context.source__builder_name . '" is not found.')
    return []
  endif

  if !unite#util#has_vimproc()
    call unite#print_message('[build] no vimproc is detected.')
    return []
  endif

  if has('signs')
    " Clear previous signs.
    call s:clear_highlight()

    let s:sign_id_dict[getcwd()] = {
          \ 'id' : (s:init_id + len(s:sign_id_dict)),
          \ 'len' : 0,
          \ }
  endif

  let a:context.source__builder =
        \ s:builders[a:context.source__builder_name]

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  let cmdline = a:context.source__builder.initialize(
        \ a:context.source__builder_args, a:context)
  call unite#print_message('[build] Command-line: ' . cmdline)

  " Set locale to English.
  let lang_save = $LANG
  let $LANG = 'C'
  let a:context.source__proc = vimproc#pgroup_open(cmdline, 0, 2)
  let $LANG = lang_save

  " Close handles.
  call a:context.source__proc.stdin.close()

  return []
endfunction "}}}

function! s:source.async_gather_candidates(args, context) "{{{
  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    call unite#print_message('[build] Completed.')

    let [cond, status] = a:context.source__proc.waitpid()
    if status
      call unite#print_message('[build] Build error occurred.')
    endif
    " Disable waitpid().
    call remove(a:context, 'source__proc')

    let a:context.is_async = 0
  endif

  let candidates = []
  for string in map(stdout.read_lines(-1, 300),
        \ "unite#util#iconv(v:val, 'char', &encoding)")
    let candidate = a:context.source__builder.parse(string, a:context)
    if !empty(candidate)
      call add(candidates, extend(candidate,
            \ s:default_candidate(), 'keep'))
    endif
  endfor

  if has('signs')
    " Set signs icon.
    let dict = s:sign_id_dict[getcwd()]
    for candidate in candidates
      if (candidate.type ==# 'warning' || candidate.type ==# 'error')
            \ && buflisted(candidate.filename)
        execute 'sign place' dict.id 'line='.candidate.line
              \ 'name=unite_build_'.candidate.type 'file='.candidate.filename
        let dict.len += 1
      endif
    endfor
  endif

  call map(candidates,
    \ "{
    \   'word': printf('[%-7s] : %s',
    \       substitute(v:val.type, '^.', '\\u\\0', ''), v:val.text),
    \   'kind': (filereadable(v:val.filename) &&
    \            !s:is_binary(v:val.filename)? 'jump_list' : 'common'),
    \   'action__path' : v:val.filename,
    \   'action__line' : v:val.line,
    \   'action__col' : v:val.col,
    \   'action__pattern' :
    \          unite#util#escape_pattern(v:val.pattern),
    \   'action__directory' :
    \       unite#util#path2directory(v:val.filename),
    \   'is_matched' : (v:val.type !=# 'message'),
    \   'is_multiline' : 1,
    \ }")

  return candidates
endfunction "}}}

function! s:default_candidate()
  return {
        \ 'filename' : '',
        \ 'line' : 0,
        \ 'col' : 0,
        \ 'pattern' : '',
        \ }
endfunction

function! s:init_builders()
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
endfunction

function! s:clear_highlight()
  " Clear previous signs.
  if has_key(s:sign_id_dict, getcwd())
    let dict = s:sign_id_dict[getcwd()]
    for cnt in range(1, dict.len)
      execute 'sign unplace' dict.id
    endfor

    call remove(s:sign_id_dict, getcwd())
  endif
endfunction

function! s:is_binary(filename)
  return get(readfile(a:filename, 'b', 1), 0, '') =~
        \'\%(^.ELF\|!<arch>\|^MZ\)\|[\x00-\x09\x10-\x1a\x1c-\x1f]\{5,}'
endfunction

" vim: foldmethod=marker
