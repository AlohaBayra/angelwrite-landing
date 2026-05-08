import Cocoa
import CoreGraphics

/// Erkennt Modifier-only Kombinationen via CGEventTap und liefert Push-to-Talk-Verhalten.
///
/// Erkannte Kombos:
///   - Fn + Shift   → .raw
///   - Fn + Control → .nice
///   - Fn + Option  → .calm
///
/// Debounce: Wurde die Kombination kürzer als `minHoldSeconds` gehalten,
/// wird `onCancelled` ausgelöst statt `onModifierChange?(nil)`.
/// Das verhindert Rauschen durch Fn-Key-Bounce (→ sofortige Noise-Aufnahmen).
final class ModifierShortcutWatcher {
    var onModifierChange: ((ProcessingMode?) -> Void)?
    /// Wird ausgelöst wenn eine Aufnahme wegen zu kurzer Haltezeit verworfen werden soll.
    var onCancelled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentMode: ProcessingMode?
    private var pressedAt: Date?

    /// Mindest-Haltezeit (in Sekunden) damit eine Aufnahme als gültig gilt.
    private let minHoldSeconds: TimeInterval = 0.3

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let watcher = Unmanaged<ModifierShortcutWatcher>.fromOpaque(userInfo).takeUnretainedValue()
                watcher.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            NSLog("[VoiceType] CGEventTap konnte nicht erstellt werden — fehlt Input Monitoring?")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if currentMode != nil {
            currentMode = nil
            pressedAt = nil
            DispatchQueue.main.async { [weak self] in self?.onModifierChange?(nil) }
        }
    }

    private func handle(event: CGEvent, type: CGEventType) {
        guard type == .flagsChanged else { return }

        let flags = event.flags
        let fnDown      = flags.contains(.maskSecondaryFn)
        let shiftDown   = flags.contains(.maskShift)
        let controlDown = flags.contains(.maskControl)
        let optionDown  = flags.contains(.maskAlternate)
        let cmdDown     = flags.contains(.maskCommand)

        guard !cmdDown else { releaseIfActive(tooShort: false); return }

        var detectedMode: ProcessingMode? = nil
        if      fnDown && shiftDown   && !controlDown && !optionDown { detectedMode = .raw  }
        else if fnDown && controlDown && !shiftDown   && !optionDown { detectedMode = .nice }
        else if fnDown && optionDown  && !shiftDown   && !controlDown { detectedMode = .calm }

        guard detectedMode != currentMode else { return }

        if let mode = detectedMode {
            // Neue Kombination gedrückt
            currentMode = mode
            pressedAt = Date()
            DispatchQueue.main.async { [weak self] in self?.onModifierChange?(mode) }
        } else {
            // Loslassen
            releaseIfActive(tooShort: true)
        }
    }

    private func releaseIfActive(tooShort: Bool) {
        guard currentMode != nil else { return }

        let holdTime = pressedAt.map { Date().timeIntervalSince($0) } ?? 1.0
        let wasTooShort = tooShort && holdTime < minHoldSeconds

        currentMode = nil
        pressedAt = nil

        if wasTooShort {
            DispatchQueue.main.async { [weak self] in self?.onCancelled?() }
        } else {
            DispatchQueue.main.async { [weak self] in self?.onModifierChange?(nil) }
        }
    }
}
