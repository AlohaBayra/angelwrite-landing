import Foundation
import Security

enum TranscriptionEngine: String {
    case cloud = "cloud"
    case local = "local"
}

final class Settings {
    static let shared = Settings()
    private init() {}

    private let useFallbackKey = "useFallbackShortcuts"
    private let languageHintKey = "languageHint"
    private let customNicePromptKey = "customNicePrompt"
    private let customCalmPromptKey = "customCalmPrompt"
    private let transcriptionEngineKey = "transcriptionEngine"
    private let whisperModelSizeKey = "whisperModelSize"
    private let serverURLKey = "serverURL"
    private let defaultServerURL = "https://voicetype-server-production.up.railway.app"
    private let firstLaunchDateKey = "firstLaunchDate"

    /// Länge des Probezeitraums in Tagen, in dem lokale+Raw-Aufnahme ohne
    /// Lizenzkey erlaubt ist.
    static let graceDays = 14

    var useFallbackShortcuts: Bool {
        get { UserDefaults.standard.bool(forKey: useFallbackKey) }
        set { UserDefaults.standard.set(newValue, forKey: useFallbackKey) }
    }

    var languageHint: String? {
        get { UserDefaults.standard.string(forKey: languageHintKey) }
        set { UserDefaults.standard.set(newValue, forKey: languageHintKey) }
    }

    var transcriptionEngine: TranscriptionEngine {
        get {
            let raw = UserDefaults.standard.string(forKey: transcriptionEngineKey) ?? "cloud"
            return TranscriptionEngine(rawValue: raw) ?? .cloud
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionEngineKey) }
    }

    var whisperModelSize: String {
        get { UserDefaults.standard.string(forKey: whisperModelSizeKey) ?? "base" }
        set { UserDefaults.standard.set(newValue, forKey: whisperModelSizeKey) }
    }

    /// Eigener System-Prompt für Modus „Nett". Leerer String beim Setter
    /// löscht den Eintrag (Reset auf Default).
    var customNicePrompt: String {
        get { UserDefaults.standard.string(forKey: customNicePromptKey) ?? "" }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.removeObject(forKey: customNicePromptKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: customNicePromptKey)
            }
        }
    }

    /// Eigener System-Prompt für Modus „Wut→Nett". Leerer String beim Setter
    /// löscht den Eintrag (Reset auf Default).
    var customCalmPrompt: String {
        get { UserDefaults.standard.string(forKey: customCalmPromptKey) ?? "" }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.removeObject(forKey: customCalmPromptKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: customCalmPromptKey)
            }
        }
    }

    /// Lizenzkey, mit dem der VoiceType-Server Anfragen autorisiert.
    /// Liegt im Keychain (Service: de.valuelift.voicetype, Account: license).
    var licenseKey: String? {
        get { Keychain.load(account: "license") }
        set { Keychain.save(account: "license", value: newValue ?? "") }
    }

    /// Datum des ersten App-Starts. Wird einmalig gesetzt durch
    /// recordFirstLaunchIfNeeded() und nicht mehr verändert. Basis für die
    /// Grace-Period-Berechnung.
    var firstLaunchDate: Date? {
        UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date
    }

    /// Setzt firstLaunchDate auf jetzt, falls noch nicht vorhanden.
    /// Idempotent — sollte einmal beim App-Start aufgerufen werden.
    func recordFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }
    }

    /// Tag/Uhrzeit, an dem der Probezeitraum endet (= firstLaunchDate + graceDays).
    /// Nil wenn firstLaunchDate noch nicht gesetzt ist.
    var graceEndDate: Date? {
        guard let start = firstLaunchDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.graceDays, to: start)
    }

    /// Verbleibende Tage im Probezeitraum (aufgerundet auf ganze Tage).
    /// Nil wenn firstLaunchDate noch nicht gesetzt ist; 0 wenn abgelaufen.
    var graceDaysRemaining: Int? {
        guard let end = graceEndDate else { return nil }
        let secondsRemaining = end.timeIntervalSinceNow
        if secondsRemaining <= 0 { return 0 }
        return Int(ceil(secondsRemaining / 86400))
    }

    /// True wenn firstLaunchDate gesetzt ist UND graceEndDate noch in der Zukunft liegt.
    var isInGracePeriod: Bool {
        guard let end = graceEndDate else { return false }
        return Date() < end
    }

    /// Basis-URL des VoiceType-Servers. Wird für /transcribe, /process und
    /// /validate verwendet. Trailing Slash wird beim Komponieren geschluckt.
    var serverURL: String {
        get { UserDefaults.standard.string(forKey: serverURLKey) ?? defaultServerURL }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: serverURLKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: serverURLKey)
            }
        }
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
