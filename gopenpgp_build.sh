#!/bin/bash

set -euox pipefail

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

go get -u golang.org/x/mobile/cmd/gomobile || true
go get golang.org/x/tools/go/packages || true
go install golang.org/x/mobile/cmd/gobind
go get golang.org/x/mobile || true
go get -u github.com/ProtonMail/gopenpgp || true

PACKAGE_PATH="github.com/ProtonMail/gopenpgp"
GOPENPGP_REVISION="136c0a54956e0241ff1b0c31aa34f2042588f843"

( cd "$GOPATH/src/$PACKAGE_PATH" && git checkout "$GOPENPGP_REVISION" && GO111MODULE=on go mod vendor )
patch -p0 < $GOPATH/crypto.patch

OUTPUT_PATH="$GOPATH/dist"
mkdir -p "$OUTPUT_PATH"

chmod -R u+w "$GOPATH/pkg/mod"

"$GOPATH/bin/gomobile" bind -v -ldflags="-s -w" -target ios -o "${OUTPUT_PATH}/Crypto.framework" \
    "$PACKAGE_PATH"/{crypto,armor,constants,models,subtle}
