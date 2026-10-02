# Zsh completions manager.
#
# Completion scripts live in $ZSH_COMPLETIONS_DIR, which is put on fpath before
# compinit runs, so any `_<cmd>` file dropped there is picked up automatically.
#
# Tools that can print their own completion script are listed in
# $ZSH_COMPLETIONS_LIST, one per line:
#
#   <cmd>                  # generated with `<cmd> completion zsh`
#   <cmd> <generator...>   # generated with a custom shell command
#   <cmd> @complete-c      # the binary completes itself via bash `complete -C`
#                          # (HashiCorp tools: `<cmd> -install-autocomplete`)
#
# A script is (re)generated on shell start when it is missing or the binary is
# newer than it, so upgrades are picked up without doing anything. Tools that
# are not installed are skipped.
#
# Scripts starting with `#compdef` are saved as `_<cmd>` and autoloaded; any
# other output is saved as `<cmd>.zsh` and sourced after compinit.
#
#   comp-add <cmd> [generator...]   generate, register and load in current shell
#   comp-rm <cmd>                   unregister and delete
#   comp-update [cmd...]            force regeneration (all registered by default)

: ${ZSH_COMPLETIONS_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions}
: ${ZSH_COMPLETIONS_LIST:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/completions.list}

[[ -d $ZSH_COMPLETIONS_DIR ]] || mkdir -p $ZSH_COMPLETIONS_DIR
fpath=($ZSH_COMPLETIONS_DIR $fpath)

# Prints registry entries as "<cmd>\t<generator>".
_comp_entries() {
  [[ -r $ZSH_COMPLETIONS_LIST ]] || return 0
  setopt localoptions extendedglob
  local line name gen
  local -a words
  for line in "${(@f)$(<$ZSH_COMPLETIONS_LIST)}"; do
    line=${line%%\#*}
    words=(${(z)line})
    name=$words[1]
    [[ -n $name ]] || continue
    gen=${${line##[[:space:]]#$name}##[[:space:]]#}
    print -r -- "$name"$'\t'"${gen:-$name completion zsh}"
  done
}

# _comp_gen <cmd> <generator>
_comp_gen() {
  local name=$1 gen=$2 out
  if [[ $gen == @complete-c ]]; then
    # Same as what `-install-autocomplete` appends to .zshrc, but resolving
    # the binary via PATH instead of hardcoding its location
    out="autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C ${(q)name} ${(q)name}"
  else
    out=$(eval "$gen" 2>/dev/null)
    if [[ $? -ne 0 || -z $out ]]; then
      print -u2 "comp: '$gen' failed, completion for $name not updated"
      return 1
    fi
  fi
  rm -f $ZSH_COMPLETIONS_DIR/{_$name,$name.zsh}
  if [[ ${out%%$'\n'*} == '#compdef'* ]]; then
    print -r -- "$out" > $ZSH_COMPLETIONS_DIR/_$name
  else
    print -r -- "$out" > $ZSH_COMPLETIONS_DIR/$name.zsh
  fi
}

_comp_file() {
  local f
  for f in $ZSH_COMPLETIONS_DIR/{_$1,$1.zsh}; do
    [[ -e $f ]] && { print -r -- $f; return 0 }
  done
  return 1
}

_comp_reset_dump() {
  rm -f ${ZDOTDIR:-$HOME}/.zcompdump*(N)
}

# Regenerates missing or outdated scripts of installed tools.
_comp_refresh() {
  local entry name gen file bin
  for entry in "${(@f)$(_comp_entries)}"; do
    [[ -n $entry ]] || continue
    name=${entry%%$'\t'*} gen=${entry#*$'\t'}
    bin=$commands[$name]
    [[ -n $bin ]] || continue
    file=$(_comp_file $name)
    [[ -z $file || $bin -nt $file ]] || continue
    _comp_gen $name $gen && _comp_reset_dump
  done
}

# Sources scripts that are not autoloadable completion functions. Call after compinit.
comp-source() {
  local f
  for f in $ZSH_COMPLETIONS_DIR/*.zsh(N); do
    source $f
  done
}

comp-add() {
  if (( ! $# )); then
    print -u2 "usage: comp-add <cmd> [generator...]"
    return 1
  fi
  local name=$1; shift
  local gen=${*:-$name completion zsh}
  _comp_gen $name $gen || return

  local entry=${${*:+$name $*}:-$name}
  local -a lines
  [[ -r $ZSH_COMPLETIONS_LIST ]] && lines=("${(@f)$(<$ZSH_COMPLETIONS_LIST)}")
  # Replace an existing entry in place to keep the diff minimal
  local i=${lines[(i)$name([[:space:]]*|)]}
  lines[i]=$entry
  mkdir -p ${ZSH_COMPLETIONS_LIST:h}
  print -rl -- $lines > $ZSH_COMPLETIONS_LIST
  _comp_reset_dump

  if [[ -e $ZSH_COMPLETIONS_DIR/_$name ]]; then
    unfunction _$name 2>/dev/null
    autoload -Uz _$name
    compdef _$name $name
  else
    source $ZSH_COMPLETIONS_DIR/$name.zsh
  fi
  print "comp: added $name to $ZSH_COMPLETIONS_LIST"
}

comp-rm() {
  if (( $# != 1 )); then
    print -u2 "usage: comp-rm <cmd>"
    return 1
  fi
  local name=$1
  local -a lines
  if [[ -r $ZSH_COMPLETIONS_LIST ]]; then
    lines=("${(@f)$(<$ZSH_COMPLETIONS_LIST)}")
    print -rl -- ${lines:#$name([[:space:]]*|)} > $ZSH_COMPLETIONS_LIST
  fi
  rm -f $ZSH_COMPLETIONS_DIR/{_$name,$name.zsh}
  _comp_reset_dump
  compdef -d $name 2>/dev/null
}

comp-update() {
  local entry name gen
  for entry in "${(@f)$(_comp_entries)}"; do
    [[ -n $entry ]] || continue
    name=${entry%%$'\t'*} gen=${entry#*$'\t'}
    (( $# == 0 || ${@[(Ie)$name]} )) || continue
    if [[ -z $commands[$name] ]]; then
      print "comp: $name is not installed, skipping"
      continue
    fi
    _comp_gen $name $gen && print "comp: updated $name"
  done
  _comp_reset_dump
}

_comp_refresh
