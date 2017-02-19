<img src="icon/icon_round.png" width="76"/> 

# Pass
[![GitHub release](https://img.shields.io/github/release/mssun/pass-ios.svg)](https://github.com/mssun/pass-ios/releases)
![Swift 3.1](https://img.shields.io/badge/Swift-3.1-orange.svg)

Pass is an iOS client compatible with [ZX2C4's Pass command line
application](http://www.passwordstore.org/).  It is a password manager using
GPG for encryption and Git for version control.

Pass for iOS is under *TestFlight external testing*. Drop me an email for testing. Thank you.

## Features

- Try to be compatible with Password Store command line tool
- Support to view, copy, add, edit password entries
- Encrypt and decrypt password entries by PGP keys
- Synchronize with you password Git repository
- User-friendly interface: search, long press to copy, copy and open link, etc.
- Written in Swift
- No need to jailbreak your devices
- Get from App Store (stay tuned, under review)

## Screenshots

<img src="screenshot/preview.gif" width="200"/>
<img src="screenshot/screenshot1.png" width="200"/>
<img src="screenshot/screenshot2.png" width="200"/>
<img src="screenshot/screenshot3.png" width="200"/>

## Build

1. Run carthage bootstrap: `carthage bootstrap --platform iOS`
2. Run pod install in the project root directory: `pod install`
3. Open `.xcworkspace` file in Xcode.
4. Build & Run.

## Usage

- Generate a PGP key pair
- Use the `pass` command line tool
- Push ecrypted password store to a private Git repository
- Build Pass for iOS by yourself or download from App Store
- Start to use Pass for iOS on your iPhone/iPad

For more, please read the [wiki page](https://github.com/mssun/pass-ios/wiki).

## License

MIT
