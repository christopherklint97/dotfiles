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
    
    ─ 1Password.app
    ─ Alfred 5.app
    ─ Brave Browser.app
    ─ ColorSlurp.app
    ─ Docker.app
    ─ Figma.app
    ─ Foxit PDF Reader.app
    ─ GIPHY CAPTURE.app
    ─ Horo.app
    ─ Insomnia.app
    ─ Keymapp.app
    ─ Linear.app
    ─ Messenger.app
    ─ Notion.app
    ─ OBS.app
    ─ Obsidian.app
    ─ Rectangle.app
    ─ Slack.app
    ─ Spotify.app
    ─ SteerMouse.app
    ─ Tuple.app
    ─ Visual Studio Code.app
    ─ WezTerm.app
    ─ WhatsApp.localized
    ─ Wireshark.app
    ─ Xcode.app
    ─ balenaEtcher.app
    ─ iStat Menus.app
