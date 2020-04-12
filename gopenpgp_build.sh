#!/bin/bash

set -euox pipefail

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

go get -u golang.org/x/mobile/cmd/gomobile || true
gomobile init
go get -u github.com/ProtonMail/gopenpgp || true

PACKAGE_PATH="github.com/ProtonMail/gopenpgp"
GOPENPGP_REVISION="v2.0.0"

( cd "$GOPATH/src/$PACKAGE_PATH" && git checkout "$GOPENPGP_REVISION" && GO111MODULE=on go mod vendor )
#patch -p0 < $GOPATH/crypto.patch

OUTPUT_PATH="$GOPATH/dist"
mkdir -p "$OUTPUT_PATH"
"$GOPATH/bin/gomobile" bind -v -ldflags="-s -w" -target ios -o "${OUTPUT_PATH}/Crypto.framework" \
    "$PACKAGE_PATH"/{crypto,armor,constants,models,subtle}
