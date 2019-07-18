#!/bin/bash

OLDGOPATH=$GOPATH
OLDPATH=$PATH

mkdir go
export GOPATH=$(pwd)/go

go get -u golang.org/x/mobile/cmd/gomobile
go install golang.org/x/mobile/cmd/gobind
go get golang.org/x/mobile

go get -u github.com/ProtonMail/gopenpgp

cd $GOPATH/src/github.com/ProtonMail/gopenpgp

GO111MODULE=on go mod vendor

cd $GOPATH
export PATH=$PATH:$GOPATH/bin
mkdir dist

OUTPUT_PATH="dist"
PACKAGE_PATH=github.com/ProtonMail/gopenpgp

$GOPATH/bin/gomobile bind -target ios -o ${OUTPUT_PATH}/Crypto.framework $PACKAGE_PATH/crypto $PACKAGE_PATH/armor $PACKAGE_PATH/constants $PACKAGE_PATH/models $PACKAGE_PATH/subtle


export GOPATH=$OLDGOPATH
export PATH=$OLDPATH
