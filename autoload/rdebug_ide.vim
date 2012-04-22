if !exists('g:rdebug_ide') | let g:rdebug_ide = {} | endif | let s:c = g:rdebug_ide
let s:c.started = get(s:c,'started',0)

fun! rdebug_ide#Stop()
  if !s:c.started
    throw "no ruby-debug debugging active. Can't stop!"
  endif
  let s:c.started = 0
  " call s:c.ctx.send('stop')
  " is this enough?
  call s:c.ctx.kill()
endf

fun! rdebug_ide#Start(...)
  if s:c.started
    throw "debugging was already started. Stop it using RDStop first, please!"
  endif
  let s:c.started = 1
  echom "switching syn off because Vim crashes when keeping it on ??"
  " syn off
  let override = a:0 > 0 ? a:1 : {}
  let opts = s:c.opts

  let s:c.log = []

  call extend(opts , override, "force")

  let ctx = {'cmd' : 'socat TCP:'.opts['host'].':'.opts['port'].' -'}

  " by thread id
  let ctx.execution_breakpoints = {}

  let ctx.break_points = {}

  fun ctx.log(lines)
    call async#DelayUntilNotDisturbing('rdebug-ide', {'delay-when': ['buf-invisible:'. self.log_bufnr, 'in-cmdbuf'], 'fun' : function('async#ExecInBuffer'), 'args':  [self.log_bufnr, function('append'), ['$',a:lines]]})
  endf

  let s:c.ctx = ctx
  if !has_key(opts,'log_bufnr')
    sp RDEBUG_SOCAT_PROCESS | enew
    let ctx.log_bufnr = bufnr('%')
  else
    let ctx.log_bufnr = opts.log_bufnr
  endif
  let ctx.pending = [""]

  let ctx.receive = function("rdebug_ide#Receive")

  fun ctx.terminated()
    if s:c.debugging
      call self.log(["socat died with code : ". self.status." restarting"])
    endif
    for x in keys(s:c.ctx.execution_breakpoints)
      let s:c.ctx.execution_breakpoints[x] = {}
    endfor
    for b in values(s:c.ctx.break_points)
      silent! unlet b.no
    endfor

    call rdebug_ide#UpdateBreakpointSigns()
    call rdebug_ide#UpdateExecutionBreakpointsSigns()
    if s:c.started
      " reuse same bufnr
      let s:c.started = 0
      if confirm('socat died, restart? y/[n]',"&yes\n[&N]o",2) == 'y'
        call rdebug_ide#Start({'log_bufnr' : self.log_bufnr})
      endif
    endif
  endf

  fun ctx.started()
    call self.log(["socat pid :". self.pid])
  endf

  " send command using automatic unique id
  fun ctx.send(cmd)
    call self.log('>'.a:cmd)
    call self.write(a:cmd."\n")
  endf

  call async#Exec(ctx)
  call ctx.log(["socat started using cmd: ".ctx.cmd])

  " try setting breakpoints:
  call rdebug_ide#BreakPointsBuffer()

endf

fun! rdebug_ide#Receive(...) dict
  call call(function('rdebug_ide#Receive2'), a:000, self)
endf
fun! rdebug_ide#Receive2(...) dict
  let self.received_data = get(self,'received_data','').a:1
  let lines = split(self.received_data,"\n",1)

  " process complete lines
  for l in lines[0:-2]
    " everything we receive should be xml, process
    call rdebug_ide#HandleMessage(l)
    let s .= l."\n"
  endfor

  " keep rest of line
  let self.received_data = lines[-1]

  " log lines for debugging:
  if len(s) > 0
    call async#DelayUntilNotDisturbing('process-pid'. self.pid, {'delay-when': ['buf-invisible:'. self.bufnr], 'fun' : self.delayed_work, 'args': [s, 1], 'self': self} )
  endif
endf

fun! rdebug_ide#Async(cmd)
  call feedkeys("\<esc> :".a:cmd."\<cr>")
endf

fun! rdebug_ide#AsyncMessage(s)
  call rdebug_ide#Async('echoe '.string(a:s))
endf

fun! rdebug_ide#HandleMessage(s) abort
  let j = json#decode(a:s)
  let debugView = []
  " let debugView = split(xmlO.toString(),"\n")
  let ctx = s:c.ctx
  call ctx.log(['call rdebug_ide#HandleMessage('''.substitute(a:s,"'","''",'g').''')'] + debugView)


  if type(j) == type({})
    let type = get(j, 'type', '')
    if type == 'message'
      call rdebug_ide#AsyncMessage('ruby-debug message: '.get(j,'message','').' '.get(j,'xdebug',''))
    elseif type == 'frame'
      call rdebug_ide#AsyncMessage('TODO frame')
    elseif type == 'thread'
      call rdebug_ide#AsyncMessage('thread')

    elseif type == "breakpointAdded"
      let id = j.file .':'. j.line
      let c_bs = s:c.ctx.break_points
      if has_key(c_bs, id)
        let b = c_bs[id]
        if b.delete_when_receiving_no > 0
          call ctx.send('delete '. j.no)
          let b.delete_when_receiving_no -= 1
        else
          let b.no = j.no
        endif
      else
        call rdebug_ide#AsyncMessage('internal breakpoint error?')
      endif
      call rdebug_ide#UpdateBreakpointSigns()

    elseif type == "breakpointDeleted"
      for b in values(s:c.ctx.break_points)
        if b.no == j.no
          unlet b.no
        endif
      endfor
      call rdebug_ide#UpdateBreakpointSigns()

    elseif type == "breakpoint"
      " breakpoint hit
      call rdebug_ide#Async('echom '.string('breakpoint hit: '.string(j)))
    elseif type == "breakpointEnabled"
      call rdebug_ide#AsyncMessage('TODO breakpointEnabled')
    elseif type == "breakpointDisabled"
      call rdebug_ide#AsyncMessage('TODO breakpointDisabled')
    elseif type == "suspended"
      let ctx.execution_breakpoints[j.threadId] = j
      call rdebug_ide#UpdateExecutionBreakpointsSigns()
    elseif type == "eval"
      call buf_utils#GotoBuf('RDBUG_EVAL_RESULTS', {'create_cmd':'sp'})
      call append(0, j.expression .'='. j.value)
    elseif type == "error"
      call rdebug_ide#AsyncMessage("ERROR: ". j.error)
    elseif type == "variables"
      call buf_utils#GotoBuf('RDBUG_VARIABLES', {'create_cmd':'sp'})
      normal ggdG
      for v in j.variables
        call append('$', string(v))
      endfor
      "conditionSet"
      "catchpointSet"
      "print_pp"
      "methods"
      "breakpoint"
      "exception"
      "suspended"
      "processingException"
    else
      call rdebug_ide#AsyncMessage('TODO '.type)
    endif
  else
    call rdebug_ide#AsyncMessage('bad json: dict expected')
  endif
endf


fun! rdebug_ide#ToggleLineBreakpoint()
  " yes, this implementation somehow sucks ..
  let file = expand('%')
  let line = getpos('.')[1]

  let old_win_nr = winnr()
  let old_buf_nr = bufnr('%')

  if !has_key(s:c,'var_break_buf_nr')
    call rdebug_ide#BreakPointsBuffer()
    let restore = "bufnr"
  else
    let win_nr = bufwinnr(get(s:c, 'var_break_buf_nr', -1))

    if win_nr == -1
      let restore = 'bufnr'
      exec 'b '.s:c.var_break_buf_nr
    else
      let restore = 'active_window'
      exec win_nr.' wincmd w'
    endif

  endif

  " BreakPoint buffer should be active now.
  let pattern = escape(file,'\').':'.line
  let line = file.':'.line
  normal gg
  let found = search(pattern,'', s:auto_break_end)
  if found > 0
    " remove breakpoint
    exec found.'g/./d'
  else
    " add breakpoint
    call append(0, line)
  endif
  call rdebug_ide#UpdateBreakPoints()
  if restore == 'bufnr'
    exec 'b '.old_buf_nr
  else
    exec old_win_nr.' wincmd w'
  endif
endf


fun! rdebug_ide#UpdateBreakPoints()
  let signs = []
  let points = {}
  let dict_new = {}
  call rdebug_ide#BreakPointsBuffer()

  let reg_if = '\%(\s*if\(.*\)\)\?'
  let r_line             = '^\([^:]\+\):\(\d\+\)'.reg_if
  let r_class_method     = '^\([^:]\+\)\.\([^:]\+\)$'.reg_if

  for l in getline('0',line('$'))
    if l =~ s:auto_break_end | break | endif
    if l =~ '^#' | continue | endif
    silent! unlet args
    let condition = ""

    let m = matchlist(l, r_line)
    if !empty(m)
      let point = {}
      if (filereadable(m[1]))
        let point['file'] = m[1]
      else
        let point['class'] = m[1]
      endif
      " ruby does not allow numbers to be methods
      if m[2] =~ '^\d\+$'
        let point['line'] = m[2]
      else
        let point['method'] = m[2]
      endif

      if m[3] != ''
        let point['expr'] = m[3]
      endif
    endif

    let m = matchlist(l, r_class_method)
    if !exists('point') && !empty(m)
      let point = {}
      let point['class'] = m[1]
      " ruby does not allow numbers to be methods
      if m[2] =~ '^\d\+$'
        let point['line'] = m[2]
      else
        let point['method'] = m[2]
      endif

      if m[3] != ''
        let point['expr'] = m[3]
      endif
    endif

    if exists('point')
      let point.s = get(point,'class','') . get(point,'file','') . ':' . point.line
      " \ . (has_key(point, 'expr') ? ' if '.point.expr : '')
      let point.key = point.file.':'.point.line
      let points[point.key] = point
      unlet point
    endif
  endfor

  let ctx = s:c.ctx
  let c_bs = ctx.break_points

  if !has_key(ctx,'status')
    " for active processes update breakpoints

    " remove dropped breakpoints
    for c_b in values(c_bs)
      if !has_key(points, c_b.key)
        let c_b.active = 0
        if has_key(c_b, 'no')
          call ctx.send('delete '. c_b.no)
        else
          " if it does not have a number we have to delete it as soon as we
          " receive the number ..
          let c_b.delete_when_receiving_no += 1
        endif
      endif
    endfor

    " add new breakpoints
    for b in values(points)
      if !has_key(c_bs, b.key)
        " new breakpoint
        let b.delete_when_receiving_no = 0
        let b.active = 1
        let c_bs[b.key] = b
        " create, no will be received async
        call ctx.send('break '. b.s)
      else
        " this breakpaint was used before, check status
        let b = c_bs[b.key]
        let b.active = 1
        if b.delete_when_receiving_no > 0
          " no longer delete on request
          let b.delete_when_receiving_no -= 1
        else
          " create, no will be received async
          call ctx.send('break '. b.s)
        endif
      endif
    endfor
  endif
  call rdebug_ide#UpdateBreakpointSigns()
endf


let s:auto_break_end = '== break points end =='
fun! rdebug_ide#BreakPointsBuffer()
  let buf_name = "RDEBUG_BREAK_POINTS_VIEW"
  let cmd = buf_utils#GotoBuf(buf_name, {'create_cmd':'sp'} )
  if cmd == 'e'
    " new buffer, set commands etc
    let s:c.var_break_buf_nr = bufnr('%')
    noremap <buffer> <cr> :call rdebug_ide#UpdateBreakPoints()<cr>
    call append(0,['# put the breakpoints here, prefix with # to deactivate:', s:auto_break_end
          \ , 'rdebug supports different types of breakpoints:'
          \ , '[file:|class:]<line|method>'
          \ , '[class.]<line|method>'
          \ , 'you always have to add the file / class in Vim'
          \ , 'hit <cr> to send updated breakpoints to processes'
          \ ])
    setlocal noswapfile
    " it may make sense storing breakpoints. So allow writing the breakpoints
    " buffer
    " set buftype=nofile
  endif

  let buf_nr = bufnr(buf_name)
  if buf_nr == -1
    exec 'sp '.fnameescape(buf_name)
  endif
endf

fun! rdebug_ide#UpdateBreakpointSigns()
  " due to async operations there are different breakpoint states:
  " active = 0/1 (which is what the state should be)
  " "no" assigned: breakpoint actually is active (the debugger sent back this
  " status)
  let c_bs = s:c.ctx.break_points

  " first char 1/0 = target state
  " second char 1/0 = number assigned (current active state in debugger)
  let d = {
    \ '11' : {'list': [], 'name': "rdebug_ide_breakpoint_active"},
    \ '10' : {'list': [], 'name': "rdebug_ide_breakpoint_activating"},
    \ '00' : {'list': [], 'name': ""},
    \ '01' : {'list': [], 'name':"rdebug_ide_breakpoint_deleting"}
    \ }
  
  for b in values(c_bs)
    let dd = d[get(b,'active',0).has_key(b,'no')]
    call add(dd.list, [bufnr(b.file), b.line * 1, dd.name])
  endfor
  call vim_addon_signs#Push("rdebug_ide_breakpoint_activating", d['10'].list)
  call vim_addon_signs#Push("rdebug_ide_breakpoint_active", d['11'].list)
  call vim_addon_signs#Push("rdebug_ide_breakpoint_deleting", d['01'].list)
endf

fun! rdebug_ide#UpdateExecutionBreakpointsSigns()
  for [threadId,j] in items(s:c.ctx.execution_breakpoints)
    let k = 'did_sign_bp_'. threadId
    let sig = 'rdebug_ide_current_line_'. threadId
    " if !has_key(s:c, k)
      let s:c[k] = 1
      exec 'sign define '.sig.' text=>'. threadId .' linehl=Type'
    " endif
    if empty(j)
      call vim_addon_signs#Push(sig, [] )
    else
      call vim_addon_signs#Push(sig, [[bufnr(j.file), j.line, sig]] )
    endif
    unlet k j
  endfor
endf
