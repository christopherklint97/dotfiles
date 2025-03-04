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

## List of desktop applications

Here is a list of desktop applications that I use on a daily basis. These can be installed in addition to the dotfiles.

* 1Password.app
* Alfred 5.app
* Brave Browser.app
* ColorSlurp.app
* Docker.app
* Insomnia.app
* Keymapp.app
* Messenger.app
* Obsidian.app
* Rectangle.app
* Slack.app
* Spotify.app
* SteerMouse.app
* Visual Studio Code.app
* WezTerm.app
* WhatsApp.localized
* balenaEtcher.app
* iStat Menus.app

## Aliases for zsh

```zsh
alias ls="ls -lahG"
alias ga="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gs="git status"
alias gd="git diff"
alias gl="git log"
alias ghprc="gh pr create -a @me"
alias ghprv="gh pr view -w"
alias ghrv="gh repo view -w"
alias ghprm="gh pr merge"
```


