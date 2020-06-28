//
//  TokenBuilder.swift
//  passKit
//
//  Created by Danny Moesch on 01.12.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import Base32
import OneTimePassword

/// Help building an OTP token from given data.
///
/// There is currently support for TOTP and HOTP tokens:
///
/// * Necessary TOTP data
///   * secret: `secretsecretsecretsecretsecretsecret`
///   * type: `totp`
///   * algorithm: `sha1` (default: `sha1`, optional)
///   * period: `30` (default: `30`, optional)
///   * digits: `6` (default: `6`, optional)
///
/// * Necessary HOTP data
///   * secret: `secretsecretsecretsecretsecretsecret`
///   * type: `hotp`
///   * counter: `1`
///   * digits: `6` (default: `6`, optional)
///
class TokenBuilder {
    private var name: String = ""
    private var secret: Data?
    private var type: OTPType = .totp
    private var algorithm: Generator.Algorithm = .sha1
    private var digits: Int? = Constants.DEFAULT_DIGITS
    private var period: Double? = Constants.DEFAULT_PERIOD
    private var counter: UInt64? = Constants.DEFAULT_COUNTER

    func usingName(_ name: String) -> TokenBuilder {
        self.name = name
        return self
    }

    func usingSecret(_ secret: String?) -> TokenBuilder {
        if secret != nil, let secretData = MF_Base32Codec.data(fromBase32String: secret!), !secretData.isEmpty {
            self.secret = secretData
        }
        return self
    }

    func usingType(_ type: String?) -> TokenBuilder {
        self.type = OTPType(name: type)
        return self
    }

    func usingAlgorithm(_ algorithm: String?) -> TokenBuilder {
        switch algorithm?.lowercased() {
        case Constants.SHA256:
            self.algorithm = .sha256
        case Constants.SHA512:
            self.algorithm = .sha512
        default:
            self.algorithm = .sha1
        }
        return self
    }

    func usingDigits(_ digits: String?) -> TokenBuilder {
        self.digits = digits == nil ? nil : Int(digits!)
        return self
    }

    func usingPeriod(_ period: String?) -> TokenBuilder {
        self.period = period == nil ? nil : Double(period!)
        return self
    }

    func usingCounter(_ counter: String?) -> TokenBuilder {
        self.counter = counter == nil ? nil : UInt64(counter!)
        return self
    }

    func build() -> Token? {
        guard secret != nil, digits != nil else {
            return nil
        }

        switch type {
        case .totp:
            return period == nil ? nil : createToken(factor: Generator.Factor.timer(period: period!))
        case .hotp:
            return counter == nil ? nil : createToken(factor: Generator.Factor.counter(counter!))
        default:
            return nil
        }
    }

    private func createToken(factor: Generator.Factor) -> Token? {
        guard let generator = Generator(factor: factor, secret: secret!, algorithm: algorithm, digits: digits!) else {
            return nil
        }
        return Token(name: name, issuer: "", generator: generator)
    }
}
