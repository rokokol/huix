# yazi's `:`. The input yazi has completes a path alone, so the command line here is zsh's own.
# The files yazi passes, the selection or else the hovered file, are "$@"

# vared completes the value of a parameter, which is a path alone; _normal reads the line as a
# command line
compdef _normal -vared-

cmd=
vared -h -p '%F{blue}:%f ' cmd
[[ -n $cmd ]] || exit 0

print -s -- "$cmd"
fc -AI
eval "$cmd"
