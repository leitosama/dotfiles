source $HOME/.antigen.zsh

antigen init < $HOME/.config/.antigenrc
export PATH=$PATH:$HOME/.local/bin:$HOME/go/bin:$HOME/.pdtm/go/bin
eval "$(starship init zsh)"
alias vim="vim"
alias vi="vim"
alias oldvim="vim"
alias git-github="git config --global user.name leitosama;git config --global user.email fs.leito@gmail.com"
export EDITOR=/bin/vim
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
