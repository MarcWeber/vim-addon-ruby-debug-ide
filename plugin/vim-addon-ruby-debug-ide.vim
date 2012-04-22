if !exists('g:rdebug_ide') | let g:rdebug_ide = {} | endif | let s:c = g:rdebug_ide
command! -bar -nargs=0 RDStart let g:rdebug_ide.debugging = 1 | call RDMappings() | call rdebug_ide#Start()
" command! -bar -nargs=0 RDKill  let g:rdebug_ide.debugging = 0 | call g:rdebug_ide.ctx.kill()
command! -bar -nargs=0 RDStop  call rdebug_ide#Stop()
" command! -bar -nargs=0 RDStackToQF call rdebug_ide#StackToQF()
" command! -bar -nargs=0 RDCopyKey call setreg('*', '?XDEBUG_SESSION_START=ECLIPSE_DBGP&KEY=12894211795611')
" command! -bar -nargs=0 RDVarView call rdebug_ide#VarView()
" command! -bar -nargs=0 RDBreakPoints call rdebug_ide#BreakPointsBuffer()
" command! -bar -nargs=0 RDToggleStopFirstLine let g:rdebug_ide.stop_first_line = !g:rdebug_ide.stop_first_line | echo "stop_first_line is now ".g:rdebug_ide.stop_first_line

" command! -bar -nargs=0 RDRun call rdebug_ide.ctx.send('run')

" command! -bar -nargs=1 RDSetMaxDepth    call g:rdebug_ide.ctx.send('feature_set -n max_depth -v '. <f-args>)
" command! -bar -nargs=1 RDSetMaxData    call g:rdebug_ide.ctx.send('feature_set -n max_data -v '. <f-args>)
" command! -bar -nargs=1 RDSetMaxChildren call g:rdebug_ide.ctx.send('feature_set -n max_children -v '. <f-args>)
" command! -bar -nargs=0 RDToggleLineBreakpoint call rdebug_ide#ToggleLineBreakpoint()

" command! -bar -nargs=0 RDRunTillCursor call g:rdebug_ide.ctx.send('breakpoint_set -f '. rdebug_ide#UriOfFilename(expand('%')).' -t line -n '.getpos('.')[1].' -r 1') | RDRun 

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
     command -nargs=* RDCommand :call g:rdebug_ide.ctx.send(join([<f-args>]," "))

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
