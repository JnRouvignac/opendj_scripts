#!/bin/bash -e

# gitk show only local branches
gitk --argscmd='git for-each-ref --format="%(refname)" refs/heads'

# visualize git orphan commits
gitk --all `git reflog | cut -c1-7` &

# restore WiFi after suspend
sudo systemctl restart network-manager

