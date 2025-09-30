# region zi
source "$HOME/.zi/bin/zi.zsh"
zi light zsh-users/zsh-autosuggestions
zi light zsh-users/zsh-syntax-highlighting
zi light unixorn/fzf-zsh-plugin

# endregion

# region compinit
autoload -Uz _zi
(( ${+_comps} )) && _comps[zi]=_zi
zicompinit
if [[ $commands[oc] ]]; then
  source <(oc completion zsh)
  compdef _oc oc
fi

# endregion

# region other

export PATH="$PATH:$HOME/.local/bin:$HOME/go/bin:$HOME/.pdtm/go/bin:$HOME/.yandex-cloud/bin"

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

eval "$(starship init zsh)"
# endregion

# region aliases
alias vim="vim"
alias vi="vim"
alias oldvim="vim"
export EDITOR=/bin/vim
alias git-github="git config --global user.name leitosama;git config --global user.email fs.leito@gmail.com"
alias lessh='LESSOPEN="| /usr/bin/src-hilite-lesspipe.sh %s" less -M '

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# endregion
# export ZSH_DEBUG_COMPLETION=1