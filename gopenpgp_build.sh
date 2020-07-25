#!/bin/bash

set -euox pipefail

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

PACKAGE_PATH="github.com/mssun/gopenpgp"
GOPENPGP_REVISION="gnu-dummy"
OUTPUT_PATH="$GOPATH/dist"

mkdir -p "$GOPATH"

go get golang.org/x/mobile/cmd/gomobile || true
( cd "$GOPATH/src/golang.org/x/mobile/cmd/gomobile" && git checkout 0df4eb2385467a487d418c6358313e9e838256ae )
GO111MODULE=on go get golang.org/x/mobile/cmd/gomobile@0df4eb2385467a487d418c6358313e9e838256ae || true
GO111MODULE=on go get golang.org/x/mobile/cmd/gobind@0df4eb2385467a487d418c6358313e9e838256ae || true
go get -u "$PACKAGE_PATH" || true

mkdir -p "$GOPATH/src/github.com/ProtonMail"
ln -f -s "$GOPATH/src/$PACKAGE_PATH" "$GOPATH/src/github.com/ProtonMail/gopenpgp"

( cd "$GOPATH/src/$PACKAGE_PATH" && git checkout "$GOPENPGP_REVISION" && GO111MODULE=on go mod vendor )

mkdir -p "$OUTPUT_PATH"

"$GOPATH/bin/gomobile" bind -v -ldflags="-s -w" -target ios -o "${OUTPUT_PATH}/Crypto.framework" \
    "$PACKAGE_PATH"/{crypto,armor,constants,models,subtle}
