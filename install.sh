#!/bin/sh

sudo apt install \
curl \
docker \
firefox \
kwrite \
git \
git-cola \
maven \
meld \
net-tools \
openjdk-11-dbg \
openjdk-11-doc \
openjdk-11-jdk \
openjdk-11-jdk-headless \
openjdk-11-jre \
openjdk-11-jre-headless \
openjdk-11-source \
synaptic \
terminator \
tree \
visualvm \
python3 \
python3-dev \
gcc \
libxml2-dev \
libxslt1-dev \
libssl-dev \
phantomjs \
libcurl4-openssl-dev \



curl -O https://bootstrap.pypa.io/get-pip.py; sudo python3 get-pip.py; rm get-pip.py
sudo pip install -U pip

#TODO fill in the right data there:
#git config --global user.email "your.name@example.com"
#git config --global user.name "Your Name"
git config --global alias.co checkout
git config --global alias.st status
git config --global core.editor "gedit"

