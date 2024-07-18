# Setup dotfiles on a new machine

First step is to clone this repo using `gh`.

```bash
# install brew and gh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gh
gh repo clone christopherklint97/dotfiles
```

To setup dotfiles on a new machine, run the `setup.sh` script. This script will create symlinks to the dotfiles in the home directory.

```bash
chmod +x setup.sh
./setup.sh
```
