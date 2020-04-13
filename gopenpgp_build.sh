#!/bin/bash

set -euox pipefail

mkdir -p go
export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

go get -u golang.org/x/mobile/cmd/gomobile || true
gomobile init
go get -u github.com/mssun/gopenpgp || true

PACKAGE_PATH="github.com/mssun/gopenpgp"
mkdir -p $GOPATH/src/github.com/ProtonMail
GOPENPGP_REVISION="gnu-dummy"
ln -s $GOPATH/src/github.com/mssun/gopenpgp $GOPATH/src/github.com/ProtonMail/gopenpgp

( cd "$GOPATH/src/$PACKAGE_PATH" && git checkout "$GOPENPGP_REVISION" && GO111MODULE=on go mod vendor )

OUTPUT_PATH="$GOPATH/dist"
mkdir -p "$OUTPUT_PATH"

"$GOPATH/bin/gomobile" bind -v -ldflags="-s -w" -target ios -o "${OUTPUT_PATH}/Crypto.framework" \
    "$PACKAGE_PATH"/{crypto,armor,constants,models,subtle}
