# PATH manager.
#
# Directories are appended to PATH from two lists, one per line:
#
#   $ZSH_PATH_LIST        public, lives in the dotfiles repo (symlinked)
#   $ZSH_PATH_LOCAL_LIST  private, machine-local, never committed
#
# `~` and variables like `$HOME` are expanded; `#` starts a comment.
#
#   path-add [-p] <dir>   add to the public list (-p: private) and to current PATH
#   path-rm <dir>         remove from both lists and from current PATH

: ${ZSH_PATH_LIST:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/path.list}
: ${ZSH_PATH_LOCAL_LIST:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/path.local.list}

typeset -U path

_path_entries() {
  local list line
  for list in $ZSH_PATH_LIST $ZSH_PATH_LOCAL_LIST; do
    [[ -r $list ]] || continue
    for line in "${(@f)$(<$list)}"; do
      line=${${line%%\#*}//[[:space:]]/}
      [[ -n $line ]] || continue
      line=${line/#\~/$HOME}
      print -r -- ${(e)line}
    done
  done
}

path+=(${(f)"$(_path_entries)"})

# Stores $HOME-relative dirs as ~/... so the lists stay portable.
_path_shorten() {
  local dir=${1:a}
  [[ $dir == $HOME/* ]] && dir="~/${dir#$HOME/}"
  print -r -- $dir
}

path-add() {
  local list=$ZSH_PATH_LIST
  if [[ $1 == -p ]]; then
    list=$ZSH_PATH_LOCAL_LIST
    shift
  fi
  if (( $# != 1 )); then
    print -u2 "usage: path-add [-p] <dir>"
    return 1
  fi
  local entry=$(_path_shorten $1)
  local -a lines
  [[ -r $list ]] && lines=("${(@f)$(<$list)}")
  if (( ! ${lines[(Ie)$entry]} )); then
    mkdir -p ${list:h}
    lines+=($entry)
    print -rl -- $lines > $list
  fi
  path+=(${1:a})
  print "path: added $entry to $list"
}

path-rm() {
  if (( $# != 1 )); then
    print -u2 "usage: path-rm <dir>"
    return 1
  fi
  local entry=$(_path_shorten $1) list
  local -a lines
  for list in $ZSH_PATH_LIST $ZSH_PATH_LOCAL_LIST; do
    [[ -r $list ]] || continue
    lines=("${(@f)$(<$list)}")
    (( ${lines[(Ie)$entry]} )) || continue
    print -rl -- ${lines:#$entry} > $list
    print "path: removed $entry from $list"
  done
  path=(${path:#${1:a}})
}
