<img src="icon/icon_round.png" width="76"/> 

# Pass
[![GitHub release](https://img.shields.io/github/release/mssun/pass-ios.svg)](https://github.com/mssun/pass-ios/releases)
![Swift 3.1](https://img.shields.io/badge/Swift-3.1-orange.svg)

Pass is an iOS client compatible with [ZX2C4's Pass command line
application](http://www.passwordstore.org/).  It is a password manager using
GPG for encryption and Git for version control.

## Screenshots

<img src="screenshot/screenshot1.png" width="200"/>
<img src="screenshot/screenshot2.png" width="200"/>
<img src="screenshot/screenshot3.png" width="200"/>
<img src="screenshot/screenshot4.png" width="200"/>

## Build

1. Run carthage bootstrap.
```
carthage bootstrap --platform iOS
```

2. Run pod install in the project root directory.
```
pod install
```

3. Open .xcworkspace file in Xcode.

4. Build & Run.

## Usage

- genearte a PGP key pair
- use `pass`
- push password store to a private Git repository
- start to use Pass for iOS on your iPhone/iPad

For more, please read the [wiki page](https://github.com/mssun/pass-ios/wiki).

## License

MIT
