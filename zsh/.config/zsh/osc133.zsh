# OSC 133 semantic prompt marks, so Zellij knows where each prompt, command and
# its output start and end. Enables, in Zellij scroll mode (Ctrl f):
#   [ / ]  jump to previous / next prompt
#   m      select a command together with its output (or triple-click)
#   c      copy the last command's output to the clipboard
#
# Only inside Zellij: outside it, Ghostty injects its own shell integration.
# Source after `starship init`. The B mark goes at the end of PROMPT. It uses
# the ESC-backslash terminator instead of BEL on purpose: atuin's precmd strips
# the BEL form of that exact sequence from PROMPT on every prompt.
# zsh restores $? and $pipestatus before each precmd hook, so hook order vs.
# starship does not matter.

[[ -n $ZELLIJ ]] || return 0

autoload -Uz add-zsh-hook

typeset -gi _osc133_cmd_ran=0

_osc133_precmd() {
  local ret=$?
  # D (command finished, with exit status) only if a command actually ran;
  # pressing Enter on an empty line skips preexec.
  (( _osc133_cmd_ran )) && print -n "\e]133;D;${ret}\a"
  _osc133_cmd_ran=0
  print -n "\e]133;A\a"
}

_osc133_preexec() {
  _osc133_cmd_ran=1
  print -n "\e]133;C\a"
}

add-zsh-hook precmd _osc133_precmd
add-zsh-hook preexec _osc133_preexec

PROMPT+=$'%{\e]133;B\e\\%}'
