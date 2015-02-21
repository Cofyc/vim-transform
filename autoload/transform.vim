" Table to determine runner from file extention.
let s:lang2cmd = {
      \ "rb":     "ruby",
      \ "py":     "python",
      \ "pl":     "perl",
      \ "sh":     "sh",
      \ "go":     "go run",
      \ "coffee": "coffee",
      \ "js":     "node",
      \ "lua":    "lua",
      \ }

" Utility function
function! s:dictionary_exists(var) "{{{1
  " only work for global var
  let [scope, name] = split(a:var, ':')
  return has_key(g:, name) && type(get(g:, name)) ==# 4
endfunction

function! s:str_strip(s) "{{{1
  " strip leading and trailing whilte space
  return substitute(a:s, '\v(^\s*)|(\s*$)', '', 'g')
endfunction

function! s:cmd_parse(cmd) "{{{1
  " split `cmd` to [bin, option] like following
  " ' /bin/ls -l ' => ['/bin/ls', ' -l']
  " '/bin/ls'      => ['/bin/ls', '']
  let cmd = s:str_strip(a:cmd)
  let i = stridx(cmd, ' ')
  if i ==# -1
    let bin = cmd
    let opt = ''
  else
    let bin =  strpart(cmd, 0, i)
    let opt =  strpart(cmd, i)
  endif
  return [bin, opt]
endfunction

" Default options
let s:options_default = {
      \ 'enable_default_config': 1,
      \ 'path': '',
      \ }

" Main
let s:T = {}
let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')

function! s:status(msg) "{{{1
  if a:msg ==# 'SUCCESS'
    return
  endif
  echom 'transform:' a:msg
endfunction

function! s:T.read_config() "{{{1
  let conf_user =
        \ s:dictionary_exists('g:transform')
        \ ? g:transform
        \ : {}

  let conf = extend({ 'options': s:options_default }, conf_user)

  if conf.options.enable_default_config
    call extend(conf,  transform#route#default(), 'keep')
  endif
  return conf
endfunction

function! s:T.handle() "{{{1
  let handlers = [self.env.buffer.filetype, "_" ]

  for handler in handlers
    unlet! TF
    let TF = get(self.conf, handler)
    if type(TF) !=# 2
      continue
    endif
    call call(TF, [self.env], self.conf)
  endfor

  throw "NOTHING_TODO"
endfunction

function! s:T.find_transformer(filename)
  let path  = join([self.conf.options.path, self.env.path.dir_transformer], ',')
  let found = split(globpath(path, a:filename), "\n")
  if !empty(found)
    return found[0]
  endif
  throw "TRANSFORMER_NOT_FOUND"
endfunction


function! s:T.run(...) "{{{1
  " TF => transformer
  try
    let [cmd; other] = a:000

    let [TF, TF_opt] = s:cmd_parse(cmd)

    let TF = expand(TF)
    let TF_with_slash = stridx(TF[1:],'/') !=# -1
    let TF_path =
          \ (TF[0] ==# '/' || !TF_with_slash) ? TF : self.find_transformer(TF)

    let cmd   = self.get_cmd(TF_path)
    let stdin = self.env.content.all
    call self.env.content.update( split(system(cmd . TF_opt, stdin), '\n' ))

    if !empty(self.env.content.all)
      call self.write()
    endif
  endtry
endfunction

function! s:T.start(...) "{{{1
  " TF => transformer
  let [line_s, line_e, mode; other] = a:000
  let TF = len(other) ==# 1 ? other[0] : ''
  try
    let self.env     = transform#environment#new(line_s, line_e, mode)
    let self.env.app = self
    let self.conf    = self.read_config()

    if !empty(TF)
      " user specify transformer explicitly
      call self.run(TF)
    else
      " heuristic
      call self.handle()
    endif
  catch
    call s:status(v:exception)
  endtry
endfunction

function! s:T.write() "{{{1
  if self.env.mode ==# 'v'
    normal! gv"_d
  else
    normal! "_dd
  endif
  call append(self.env.buffer['line_s-1'], self.env.content.all)
endfunction

function! s:T.get_cmd(tf) "{{{1
  if !s:is_windows && executable(a:tf)
    return a:tf
  endif
  let ext = fnamemodify(a:tf, ":t:e")
  let rc  = get(s:lang2cmd, ext, '')

  if  empty(rc)      | throw "CANT_DETERMINE_RUNNER"         | endif
  if !executable(rc) | throw "RUNNER_NOT_EXCUTETABLE: " . rc | endif

  return rc . ' ' . a:tf
endfunction

" Public API
function! transform#start(...) "{{{1
  call call(s:T.start, a:000, s:T)
endfunction

function! transform#config() "{{{1
  return s:T.read_config()
endfunction
" }}}
" vim: foldmethod=marker
