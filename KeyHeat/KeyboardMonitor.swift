@preconcurrency import CoreGraphics
import Foundation

struct ModifierPressState {
    private var pressedCodes: Set<CGKeyCode> = []

    mutating func transition(code: CGKeyCode, isDown: Bool) -> CGKeyCode? {
        if isDown {
            return pressedCodes.insert(code).inserted ? code : nil
        }
        pressedCodes.remove(code)
        return nil
    }

    mutating func reset() {
        pressedCodes.removeAll()
    }
}

enum KeyboardEventFilter {
    static func physicalKeyCode(
        type: CGEventType,
        keyCode: CGKeyCode,
        isRepeat: Bool,
        modifierIsDown: Bool,
        modifierState: inout ModifierPressState
    ) -> CGKeyCode? {
        if type == .keyDown {
            return isRepeat ? nil : keyCode
        }

        guard type == .flagsChanged else { return nil }
        if keyCode == 57 {
            return keyCode
        }
        return modifierState.transition(code: keyCode, isDown: modifierIsDown)
    }
}

@MainActor
final class KeyboardMonitor: ObservableObject {
    enum Status: Equatable {
        case stopped
        case permissionRequired
        case running
        case failed(String)
    }

    @Published private(set) var status: Status = .stopped
    var onPhysicalKeyDown: ((CGKeyCode) -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierState = ModifierPressState()

    var hasPermission: Bool {
        CGPreflightListenEventAccess()
    }

    func requestPermission() -> Bool {
        let granted = CGRequestListenEventAccess()
        updateStatus(granted ? .stopped : .permissionRequired)
        return granted
    }

    func start() {
        guard CGPreflightListenEventAccess() else {
            stop()
            updateStatus(.permissionRequired)
            return
        }

        if status == .running, let eventTap, CFMachPortIsValid(eventTap) {
            return
        }

        stop()

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return MainActor.assumeIsolated {
                    monitor.handle(type: type, event: event)
                }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            updateStatus(.failed("无法创建输入监听，请检查输入监控权限。"))
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            updateStatus(.failed("无法启动输入监听。"))
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        updateStatus(.running)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        modifierState.reset()
        if status == .running {
            updateStatus(.stopped)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let modifierIsDown = CGEventSource.keyState(.combinedSessionState, key: keyCode)

        if let physicalKey = KeyboardEventFilter.physicalKeyCode(
            type: type,
            keyCode: keyCode,
            isRepeat: isRepeat,
            modifierIsDown: modifierIsDown,
            modifierState: &modifierState
        ) {
            onPhysicalKeyDown?(physicalKey)
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateStatus(_ newStatus: Status) {
        status = newStatus
        onStatusChange?(newStatus)
    }
}
