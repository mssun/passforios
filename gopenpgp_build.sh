#!/bin/bash

OLDGOPATH=$GOPATH
OLDPATH=$PATH

export GOPATH=$(pwd)/go

go get -u golang.org/x/mobile/cmd/gomobile
go install golang.org/x/mobile/cmd/gobind
go get golang.org/x/mobile

go get -u github.com/ProtonMail/gopenpgp

cd $GOPATH/src/github.com/ProtonMail/gopenpgp

git fetch && git fetch --tags

git checkout v0

GO111MODULE=on go mod vendor

git checkout v1.0.0

cd $GOPATH
export PATH=$PATH:$GOPATH/bin
mkdir dist

$GOPATH/bin/gomobile bind -target ios -o dist/Gopenpgpwrapper.framework gopenpgpwrapper

export GOPATH=$OLDGOPATH
export PATH=$OLDPATH
