if !exists('g:rdebug_ide') | let g:rdebug_ide = {} | endif | let s:c = g:rdebug_ide

let s:c.rdebug_ide_cmd = get(s:c, 'rdebug_ide_cmd', 'rdebug-ide -J %')

command! -bar -nargs=0 RDStart call RDMappings() | call rdebug_ide#Start()
command! -bar -nargs=0 RDStop  call rdebug_ide#Stop()

sign define rdebug_ide_breakpoint_activating text=O<   linehl=
sign define rdebug_ide_breakpoint_deleting   text=O>   linehl=
sign define rdebug_ide_breakpoint_active     text=O    linehl=

if !exists('*RDMappings')
  fun! RDMappings()
     " step into
     noremap <F5> :call g:rdebug_ide.ctx.send('step')<cr>
     " next command same level
     noremap <F6> :call g:rdebug_ide.ctx.send('next')<cr>
     " step out
     noremap <F7> :call g:rdebug_ide.ctx.send('finish')<cr>
     noremap <F8> :call g:rdebug_ide.ctx.send('cont')<cr>
     noremap <F9> :call rdebug_ide#ToggleLineBreakpoint()<cr>
     " noremap \xv :RDVarView<cr>
     " vnoremap \xv y:RDVarView<cr>GpV<cr>
     command! -nargs=* RDCommand call g:rdebug_ide.ctx.send(join([<f-args>]," "))
     " custom watch expressions, eval result view:
     command! -nargs=0 RDEvalView call rdebug_ide#EvalView()
     command! -nargs=* RDWatch call rdebug_ide#EvalView()|call append(0,'watch '.input('watch', <f-args>))

      " TODO implement these commands in some way
      "      class AddBreakpoint < Command # :nodoc:
      "      class BreakpointsCommand < Command # :nodoc:
      "      class DeleteBreakpointCommand < Command # :nodoc:
      "      class CatchCommand < Command # :nodoc:
      "      class ConditionCommand < Command # :nodoc:
      "      class QuitCommand < Command # :nodoc:
      "      class RestartCommand < Command # :nodoc:
      "      class StartCommand < Command # :nodoc:
      "      class InterruptCommand < Command # :nodoc:
      "      class EnableCommand < Command # :nodoc:
      "      class DisableCommand < Command # :nodoc:
      "      class EvalCommand < Command # :nodoc:
      "      class PPCommand < Command # :nodoc:
      "      class WhereCommand < Command # :nodoc:
      "      class UpCommand < Command # :nodoc:
      "      class DownCommand < Command # :nodoc:
      "      class FrameCommand < Command # :nodoc:
      "      class InspectCommand < Command
      "      class JumpCommand < Command
      "      class LoadCommand < Command  
      "      class PauseCommand < Command
      "      class FinishCommand < Command # :nodoc:
      "      class ContinueCommand < Command # :nodoc:
      "      class ThreadListCommand < Command # :nodoc:
      "      class ThreadSwitchCommand < Command # :nodoc:
      "      class ThreadStopCommand < Command # :nodoc:
      "      class ThreadCurrentCommand < Command # :nodoc:
      "      class ThreadResumeCommand < Command # :nodoc:
      "      class VarConstantCommand < Command # :nodoc:
      "      class VarGlobalCommand < Command # :nodoc:
      "      class VarInstanceCommand < Command # :nodoc:
      "      class VarLocalCommand < Command # :nodoc:
      "      class SetTypeCommand < Command

  endf
endif

let s:c.opts = get(s:c,'opts',{'port': '1234', 'host': 'localhost'})
