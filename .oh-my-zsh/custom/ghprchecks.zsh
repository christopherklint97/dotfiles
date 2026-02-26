function ghprchecks() {
  if [[ "$1" == "--json" ]]; then
    gh pr checks --json name,state,link
  else
    gh pr checks --watch
  fi
}

