#!/bin/bash -e

# gitk show only local branches
gitk --argscmd='git for-each-ref --format="%(refname)" refs/heads'

# visualize git orphan commits
gitk --all `git reflog | cut -c1-7` &

# restore WiFi after suspend
sudo systemctl restart network-manager

# fix eclipse .classpath
find . -name .classpath | xargs sed 's/26.0.0-20191206110111-136b5fa/26.1.0-20200918174936-87989f3/g' -i
find . -name .classpath | xargs sed 's@M2_REPO/org/assertj/assertj-core/3.6.2/assertj-core-3.6.2@M2_REPO/org/assertj/assertj-core/3.15.0/assertj-core-3.15.0@g' -i

