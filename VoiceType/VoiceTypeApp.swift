import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let fallbackRaw = Self("fallbackRaw", default: .init(.r, modifiers: [.command, .option]))
    static let fallbackNice = Self("fallbackNice", default: .init(.n, modifiers: [.command, .option]))
    static let fallbackCalm = Self("fallbackCalm", default: .init(.w, modifiers: [.command, .option]))
}

@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Platzhalter-Scene: Das Settings-Fenster wird in AppDelegate.openSettings
        // selbst als NSWindow + NSHostingController erzeugt, weil SwiftUI's
        // Settings-Scene unter LSUIElement nicht zuverlässig in den Vordergrund
        // kommt.
        SwiftUI.Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()
    private var statusItem: NSStatusItem!
    private let modifierWatcher = ModifierShortcutWatcher()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
        updateStatusIcon()

        coordinator.onStateChange = { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusIcon() }
        }

        setupShortcuts()
        coordinator.checkPermissionsOnStartup()
    }

    private func setupShortcuts() {
        if Settings.shared.useFallbackShortcuts {
            startFallbackShortcuts()
        } else {
            startModifierShortcuts()
        }
    }

    private func startModifierShortcuts() {
        // Push-to-Talk: drücken & halten = aufnehmen, loslassen = stop
        modifierWatcher.onModifierChange = { [weak self] mode in
            guard let self = self else { return }
            if let mode = mode {
                // Modifier wurde gedrückt
                if !self.coordinator.isRecording {
                    self.coordinator.startRecording(mode: mode)
                }
            } else {
                // Modifier wurde losgelassen
                if self.coordinator.isRecording {
                    self.coordinator.stopRecording()
                }
            }
        }
        modifierWatcher.start()
    }

    private func startFallbackShortcuts() {
        // Toggle-Verhalten für klassische Shortcuts
        KeyboardShortcuts.onKeyDown(for: .fallbackRaw) { [weak self] in
            self?.coordinator.toggle(mode: .raw)
        }
        KeyboardShortcuts.onKeyDown(for: .fallbackNice) { [weak self] in
            self?.coordinator.toggle(mode: .nice)
        }
        KeyboardShortcuts.onKeyDown(for: .fallbackCalm) { [weak self] in
            self?.coordinator.toggle(mode: .calm)
        }
    }

    func reloadShortcuts() {
        modifierWatcher.stop()
        KeyboardShortcuts.removeAllHandlers()
        setupShortcuts()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status: \(coordinator.statusDescription)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        if Settings.shared.useFallbackShortcuts {
            menu.addItem(NSMenuItem(title: "Aufnahme: ⌘⌥R / ⌘⌥N / ⌘⌥W", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Halten: Fn+⇧ / Fn+⌃ / Fn+⌥", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Einstellungen…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        let state = coordinator.state
        let symbol: String
        var tint: NSColor? = nil
        var modeLetter: String? = nil

        switch state {
        case .idle:
            symbol = "mic"
        case .recording(let mode):
            symbol = "mic.fill"
            tint = .systemRed
            modeLetter = mode.letter
        case .processing:
            symbol = "waveform"
            tint = .systemBlue
        case .done:
            symbol = "checkmark.circle.fill"
            tint = .systemGreen
        case .error:
            symbol = "exclamationmark.triangle.fill"
            tint = .systemOrange
        }

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "VoiceType")
        image?.isTemplate = (tint == nil)

        if let button = statusItem.button {
            button.image = image
            button.contentTintColor = tint
            button.title = modeLetter.map { " \($0)" } ?? ""
        }

        rebuildMenu()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView().environmentObject(coordinator)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "VoiceType – Einstellungen"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("VoiceTypeSettings")
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
