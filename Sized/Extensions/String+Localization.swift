import Foundation

extension String {
    var localized: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }

    func localizedFormat(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: Locale.current, arguments: arguments)
    }
}
