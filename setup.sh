# Install packages from Brewfile

brew bundle --file=~/dotfiles/Brewfile

# Install oh-my-zsh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# install nvm

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Create symlinks

stow .
