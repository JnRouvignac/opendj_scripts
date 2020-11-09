#!/bin/bash -e

# gitk show only local branches
gitk --argscmd='git for-each-ref --format="%(refname)" refs/heads'

# visualize git orphan commits
gitk --all `git reflog | cut -c1-7` &

# restore WiFi after suspend
sudo systemctl restart network-manager

# switch java version
sudo update-alternatives --config java
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64

# add current user to docker user group
sudo usermod -aG docker $USER.

# fix eclipse .classpath
find . -name .classpath | xargs sed 's/26.0.0-20191206110111-136b5fa/26.1.0-20200918174936-87989f3/g' -i
find . -name .classpath | xargs sed 's@M2_REPO/org/assertj/assertj-core/3.6.2/assertj-core-3.6.2@M2_REPO/org/assertj/assertj-core/3.15.0/assertj-core-3.15.0@g' -i

