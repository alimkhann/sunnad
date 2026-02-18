import Foundation

enum L10n {
    private static var languageCodeOverride: String?

    static func setLanguage(code: String) {
        languageCodeOverride = code
    }

    static func t(_ key: String) -> String {
        if let override = languageCodeOverride,
           let path = Bundle.main.path(forResource: override, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
            if localized != key {
                return localized
            }
        }

        return NSLocalizedString(key, comment: "")
    }
}
