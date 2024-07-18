# Install packages from Brewfile

brew bundle --file=~/dotfiles/Brewfile

# Install oh-my-zsh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Create symlinks

stow .
