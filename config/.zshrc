source $HOME/.antigen.zsh

antigen init < $HOME/.config/.antigenrc
export PATH=$PATH:$HOME/.local/bin:$HOME/go/bin
eval "$(starship init zsh)"
alias vim="nvim"
alias vi="nvim"
alias oldvim="vim"
export EDITOR=/bin/nvim
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
