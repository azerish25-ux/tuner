import Foundation
import TimbreCore

/// Resolve imperative copy through the same selected language as SwiftUI's Locale.
func NSLocalizedString(_ key: String, tableName: String? = nil, bundle: Bundle = .main, value: String = "", comment: String) -> String {
    Foundation.NSLocalizedString(key, tableName: tableName, bundle: bundle == .main ? TimbreLocalization.bundle : bundle, value: value, comment: comment)
}
