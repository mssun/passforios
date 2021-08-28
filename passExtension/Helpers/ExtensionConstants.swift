//
//  ExtensionConstants.swift
//  passExtension
//
//  Created by Yishi Lin on 2017/6/23.
//  Copyright © 2017 Bob Sun. All rights reserved.
//
//  This file contains constants from https://github.com/agilebits/onepassword-app-extension/

enum PassExtensionActions {
    static let findLogin = "org.appextension.find-login-action"
    static let saveLogin = "org.appextension.save-login-action"
    static let changePassword = "org.appextension.change-password-action"
    static let fillWebView = "org.appextension.fill-webview-action"
    static let fillBrowser = "org.appextension.fill-browser-action"
}

enum PassExtensionKey {
    // Login Dictionary keys
    static let URLStringKey = "url_string"
    static let usernameKey = "username"
    static let passwordKey = "password"
    static let totpKey = "totp"
    static let titleKey = "login_title"
    static let notesKey = "notes"
    static let sectionTitleKey = "section_title"
    static let fieldsKey = "fields"
    static let returnedFieldsKey = "returned_fields"
    static let oldPasswordKey = "old_password"
    static let passwordGeneratorOptionsKey = "password_generator_options"

    // Password Generator options
    static let generatedPasswordMinLengthKey = "password_min_length"
    static let generatedPasswordMaxLengthKey = "password_max_length"
    static let generatedPasswordRequireDigitsKey = "password_require_digits"
    static let generatedPasswordRequireSymbolsKey = "password_require_symbols"
    static let generatedPasswordForbiddenCharactersKey = "password_forbidden_characters"
}
