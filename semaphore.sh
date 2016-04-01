#!/bin/bash

set -e

if [ "$1" = "setup" ] ; then
  sudo groupadd rkt
  sudo gpasswd -a runner rkt
  exit 0
fi

# Set up go environment on semaphore
if [ -f /opt/change-go-version.sh ]; then
    . /opt/change-go-version.sh
    change-go-version 1.5
fi

export GOPATH=$HOME/go
mkdir -p $GOPATH
mkdir -p $GOPATH/bin
export PATH=$PATH:$GOPATH/bin

git config --global user.email "you@example.com"
git config --global user.name "Semaphore Script godep-rkt-test"

# select rkt sources
cd
if [ "$SEMAPHORE_CURRENT_THREAD" = "1" ] ; then
  BRANCH=master
elif [ "$SEMAPHORE_CURRENT_THREAD" = "2" ] ; then
  echo "Build disabled"
  exit 0
else
  echo "SEMAPHORE_CURRENT_THREAD=$SEMAPHORE_CURRENT_THREAD"
  exit 1
fi

# install godeps
go get github.com/tools/godep
go build github.com/tools/godep
godep version

# get rkt sources
go get github.com/coreos/rkt || true
cd $GOPATH/src/github.com/coreos/rkt
git checkout $BRANCH

echo "rkt git branch: $BRANCH"
echo "rkt git describe: $(git describe HEAD)"
echo "Last two rkt commits:"
git log -n 2 | cat
echo

# update godeps
echo "### getting deps"
go get github.com/appc/cni || true
go get github.com/appc/spec || true
go get github.com/appc/docker2aci || true
go get go4.org/errorutil || true
echo "### godep restore"
godep restore -v
echo "### updating repositories"
(cd $GOPATH/src/github.com/appc/cni && git pull origin master)
(cd $GOPATH/src/github.com/appc/docker2aci && git pull origin master)
(cd $GOPATH/src/github.com/godbus/dbus && git pull origin master)
(cd $GOPATH/src/github.com/appc/spec && git pull origin master)
echo "### godep-save"
./scripts/godep-save
echo "### git status"
git status
echo "### git diff"
git diff --no-color | cat
echo "###"

# updates
./tests/install-deps.sh

# Test
./autogen.sh
./configure --enable-functional-tests \
      --with-stage1-flavors=coreos,fly \
      --enable-tpm=no

make -j 4
make check
