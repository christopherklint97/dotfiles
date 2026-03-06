# Git aliases

alias ga="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gs="git status"
alias gd="git diff"
alias gl="git log"
alias grsh="git reset --soft HEAD~1"

# GitHub CLI aliases

alias ghprv="gh pr view -w"
alias ghprl="gh pr view --json url --jq '.url' | pbcopy && echo 'PR link copied to clipboard'"
alias ghrv="gh repo view -w"

## Watch the latest convox.yml workflow run
alias ghconvox="gh run list --workflow=convox.yml --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch"

## Watch the latest deploy.yml workflow run
alias ghdeploy="gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch"

# Claude
alias claude="claude --dangerously-skip-permissions"

# Other

alias pip="pip3"
alias vim="nvim"
alias ls="ls -lahG"
alias grep="grep -i"
alias capstatus="crontab -l && echo '' && echo 'Active cpulimit processes:' && ps aux | grep cpulimit | grep -v grep || echo 'None'"
