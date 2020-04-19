#!/bin/bash

set -euox pipefail

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

PACKAGE_PATH="github.com/mssun/gopenpgp"
GOPENPGP_REVISION="gnu-dummy"
OUTPUT_PATH="$GOPATH/dist"

mkdir -p "$GOPATH"

go get -u golang.org/x/mobile/cmd/gomobile || true
gomobile init
go get -u "$PACKAGE_PATH" || true

mkdir -p "$GOPATH/src/github.com/ProtonMail"
ln -s "$GOPATH/src/$PACKAGE_PATH" "$GOPATH/src/github.com/ProtonMail/gopenpgp"

( cd "$GOPATH/src/$PACKAGE_PATH" && git checkout "$GOPENPGP_REVISION" && GO111MODULE=on go mod vendor )

mkdir -p "$OUTPUT_PATH"

"$GOPATH/bin/gomobile" bind -v -ldflags="-s -w" -target ios -o "${OUTPUT_PATH}/Crypto.framework" \
    "$PACKAGE_PATH"/{crypto,armor,constants,models,subtle}
