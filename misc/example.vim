let g:transform = {}
let g:transform.options = {}
let g:transform.options.enable_default_config = 0
let g:transform.options.path = "/Users/t9md/transformer"

function! g:transform._(e)
  let e = a:e
  let c = e.content

  if e.buffer.filetype ==# 'go'
    if c.line_s =~# '\v^const\s*\(' && c.line_e =~# '\v\)\s*'
      call e.run("go/const_stringfy.rb")
    elseif c['line_s-1'] =~# '\v^import\s*\('
      call e.run("go/import.rb")
    endif
  endif

  if e.buffer.filetype =~# 'markdown'
    " Dangerous example
    " if line is four leading space and '$', then execute string after '$' char.
    "  ex) '    $ ls -l' => trasnsformed result of 'ls -l'

    let pat = '\v^    \$(.*)$'
    if c.len ==# 1 && c.line_s =~# pat
      let cmd = substitute(c.line_s, pat, '\1', '')
      call e.run(cmd)
    endif

    " replace URL to actual content
    if c.len ==# 1 && c.line_s =~# '\v^\s*https?://\S*$'
      call e.run('curl ' . c.line_s)
    endif
  endif

  if e.buffer.filename =~# 'translate.md'
    call e.run('google_translate.py')
  endif
  call e.run("_/stringfy_word.rb")
endfunction