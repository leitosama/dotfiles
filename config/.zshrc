# If there is cache available
if [[ -f ${ADOTDIR:-$HOME/.antigen}/.cache/.zcache-payload ]]; then
    # Load bundles statically
    source ${ADOTDIR:-$HOME/.antigen}/.cache/.zcache-payload

    # You will need to call compinit
    autoload -Uz compinit
    compinit -d ${HOME}/.zcompdump
else
    # If there is no cache available do load and execute antigen
    source $HOME/.antigen.zsh

    # I'm using antigen-init here but your usual antigen-bundle,
    # antigen-theme, antigen-apply will work as well
    antigen init $HOME/.dotfiles/config/.antigenrc
fi

export PATH=$PATH:$HOME/.local/bin:$HOME/go/bin:$HOME/.pdtm/go/bin:$HOME/.yandex-cloud/bin
eval "$(starship init zsh)"
alias vim="vim"
alias vi="vim"
alias oldvim="vim"
export EDITOR=/bin/vim
alias git-github="git config --global user.name leitosama;git config --global user.email fs.leito@gmail.com"
alias lessh='LESSOPEN="| /usr/bin/src-hilite-lesspipe.sh %s" less -M '
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
if [[ -f $HOME/.yandex-cloud/completion.zsh.inc ]]; then
     source $HOME/.yandex-cloud/completion.zsh.inc
fi
source $HOME/.dotfiles/config/oc.completion.zsh
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select
