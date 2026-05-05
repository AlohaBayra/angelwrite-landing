import Foundation
import Security

final class Settings {
    static let shared = Settings()
    private init() {}

    private let useFallbackKey = "useFallbackShortcuts"
    private let languageHintKey = "languageHint"

    var useFallbackShortcuts: Bool {
        get { UserDefaults.standard.bool(forKey: useFallbackKey) }
        set { UserDefaults.standard.set(newValue, forKey: useFallbackKey) }
    }

    var languageHint: String? {
        get { UserDefaults.standard.string(forKey: languageHintKey) }
        set { UserDefaults.standard.set(newValue, forKey: languageHintKey) }
    }

    var openAIAPIKey: String? {
        get { Keychain.load(account: "openai") }
        set { Keychain.save(account: "openai", value: newValue ?? "") }
    }

    var anthropicAPIKey: String? {
        get { Keychain.load(account: "anthropic") }
        set { Keychain.save(account: "anthropic", value: newValue ?? "") }
    }
}

enum Keychain {
    private static let service = "de.valuelift.voicetype"

    static func save(account: String, value: String) {
        let data = value.data(using: .utf8) ?? Data()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        if value.isEmpty { return }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}
