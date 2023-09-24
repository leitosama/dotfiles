source $HOME/.antigen.zsh

antigen init < $HOME/.config/.antigenrc
export PATH=$PATH:$HOME/.local/bin:$HOME/go/bin
eval "$(starship init zsh)"