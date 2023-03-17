#!/bin/bash

set -euox pipefail

GOPENPGP_VERSION="v2.6.0-passforios"

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

OUTPUT_PATH="go/dist"
CHECKOUT_PATH="go/checkout"
GOPENPGP_PATH="$CHECKOUT_PATH/gopenpgp"

mkdir -p "$OUTPUT_PATH"
mkdir -p "$CHECKOUT_PATH"

git clone --depth 1 --branch "$GOPENPGP_VERSION" https://github.com/mssun/gopenpgp.git "$GOPENPGP_PATH"

pushd "$GOPENPGP_PATH"
mkdir -p dist
go get golang.org/x/mobile/cmd/gomobile@latest
go get golang.org/x/mobile/cmd/gobind@latest
go build golang.org/x/mobile/cmd/gomobile
go build golang.org/x/mobile/cmd/gobind
go mod download github.com/ProtonMail/go-crypto
gomobile init
gomobile bind -tags mobile -target ios -iosversion 13.0 -v -x -ldflags="-s -w" -o dist/Gopenpgp.xcframework \
  github.com/ProtonMail/gopenpgp/v2/crypto \
  github.com/ProtonMail/gopenpgp/v2/armor \
  github.com/ProtonMail/gopenpgp/v2/constants \
  github.com/ProtonMail/gopenpgp/v2/models \
  github.com/ProtonMail/gopenpgp/v2/subtle \
  github.com/ProtonMail/gopenpgp/v2/helper
popd

cp -r "$GOPENPGP_PATH/dist/Gopenpgp.xcframework" "$OUTPUT_PATH"

