# Install packages from Brewfile

brew bundle --file=~/dotfiles/Brewfile

# Install oh-my-zsh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Clone zsh-autosuggestions plugin

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install nvm

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Git pull submodules (e.g. nvim)

git submodule update --init --recursive

# Install tmux plugin manager

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Create symlinks and adopt the files that already exist

stow --adopt .
