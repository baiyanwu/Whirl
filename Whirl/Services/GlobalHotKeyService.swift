import AppKit
@preconcurrency import Carbon.HIToolbox
@preconcurrency import CoreGraphics
import Foundation

enum OverlayKeyboardCommand: Equatable, Sendable {
    case next
    case previous
    case confirm
    case cancel
    case digit(Int)
}

enum OverlayKeyboardMapping {
    static func command(
        for keyCode: UInt16,
        flags: CGEventFlags,
        confirmationKey: WindowConfirmationKey
    ) -> OverlayKeyboardCommand? {
        switch keyCode {
        case 48:
            return flags.contains(.maskShift) ? .previous : .next
        case 123:
            return .previous
        case 124:
            return .next
        case 53:
            return .cancel
        default:
            if confirmationKey.accepts(keyCode: keyCode) { return .confirm }
            if let digit = KeyBinding.digit(for: keyCode) { return .digit(digit) }
            return nil
        }
    }
}

@MainActor
final class GlobalHotKeyService {
    var onShowAppBar: (() -> Void)?
    var onHideAppBar: (() -> Void)?
    var onShowWindowBar: (() -> Void)?
    var onShortModifierTap: (() -> Void)?
    var onLaunchBinding: ((UUID) -> Void)?
    var onOverlayCommand: ((OverlayKeyboardCommand) -> Bool)?
    var onPermissionsUnavailable: (() -> Void)?

    private var preferences = AppPreferences.default
    private var permissions = PermissionSnapshot(accessibilityGranted: false)
    private var bindingIDsByKeyCode: [UInt16: UUID] = [:]
    private var stateMachine = ModifierGestureStateMachine()
    private var globalModifierMonitor: Any?
    private var localModifierMonitor: Any?
    private var overlayEventTap: CFMachPort?
    private var overlayRunLoopSource: CFRunLoopSource?
    private var hotKeyEventHandler: EventHandlerRef?
    private var hotKeyReferences: [UInt32: EventHotKeyRef] = [:]
    private var bindingIDsByHotKeyID: [UInt32: UUID] = [:]
    private var longPressWorkItem: DispatchWorkItem?
    private var modifierKeysDown: Set<UInt16> = []
    private var swallowedKeys: Set<UInt16> = []
    private(set) var isRunning = false
    var isSuspended = false

    func update(
        preferences: AppPreferences,
        bindings: [AppBinding],
        permissions: PermissionSnapshot
    ) {
        let modifierChanged = self.preferences.switchingModifier != preferences.switchingModifier
        self.preferences = preferences
        self.permissions = permissions
        let updatedBindings = Dictionary(uniqueKeysWithValues: bindings.map { ($0.keyBinding.keyCode, $0.id) })
        let bindingsChanged = updatedBindings != bindingIDsByKeyCode
        bindingIDsByKeyCode = updatedBindings
        if modifierChanged {
            modifierKeysDown.removeAll()
            perform(stateMachine.reset())
        }
        guard isRunning else { return }
        if bindingsChanged || modifierChanged {
            refreshHotKeyRegistrations()
        }
        refreshOverlayEventTap()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard installHotKeyEventHandler() else { return false }
        isRunning = true
        refreshHotKeyRegistrations()
        startModifierMonitors()
        refreshOverlayEventTap()
        return true
    }

    func stop() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        stopModifierMonitors()
        stopOverlayEventTap()
        unregisterHotKeys()
        if let hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
        }
        hotKeyEventHandler = nil
        modifierKeysDown.removeAll()
        swallowedKeys.removeAll()
        perform(stateMachine.reset())
        isRunning = false
    }

    private func refreshOverlayEventTap() {
        if permissions.accessibilityGranted {
            if overlayEventTap == nil {
                startOverlayEventTap()
            }
        } else {
            stopOverlayEventTap()
        }
    }

    private func startModifierMonitors() {
        guard globalModifierMonitor == nil, localModifierMonitor == nil else { return }

        globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleModifierEvent(
                    keyCode: event.keyCode,
                    timestamp: event.timestamp,
                    isPressed: self.preferences.switchingModifier.isPressed(
                        keyCode: event.keyCode,
                        in: event.modifierFlags
                    )
                )
            }
        }
        localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleModifierEvent(
                    keyCode: event.keyCode,
                    timestamp: event.timestamp,
                    isPressed: self.preferences.switchingModifier.isPressed(
                        keyCode: event.keyCode,
                        in: event.modifierFlags
                    )
                )
            }
            return event
        }
    }

    private func stopModifierMonitors() {
        if let globalModifierMonitor { NSEvent.removeMonitor(globalModifierMonitor) }
        if let localModifierMonitor { NSEvent.removeMonitor(localModifierMonitor) }
        globalModifierMonitor = nil
        localModifierMonitor = nil
        modifierKeysDown.removeAll()
        perform(stateMachine.reset())
    }

    private func startOverlayEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    service.handleOverlayEvent(type: type, event: event)
                }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        overlayEventTap = tap
        overlayRunLoopSource = source
    }

    private func stopOverlayEventTap() {
        if let overlayEventTap {
            CGEvent.tapEnable(tap: overlayEventTap, enable: false)
            CFMachPortInvalidate(overlayEventTap)
        }
        if let overlayRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), overlayRunLoopSource, .commonModes)
        }
        overlayEventTap = nil
        overlayRunLoopSource = nil
        swallowedKeys.removeAll()
    }

    func handleModifierEvent(
        keyCode: UInt16,
        timestamp: TimeInterval,
        isPressed: Bool
    ) {
        guard !isSuspended, preferences.switchingModifier.accepts(keyCode: keyCode) else { return }

        if isPressed {
            guard modifierKeysDown.insert(keyCode).inserted else { return }
            perform(stateMachine.modifierDown(keyCode: keyCode, time: timestamp, preferences: preferences))
        } else {
            let wasTrackedAsPressed = modifierKeysDown.remove(keyCode) != nil
            guard wasTrackedAsPressed || stateMachine.pressedModifierKeyCode == keyCode else { return }
            perform(stateMachine.modifierUp(keyCode: keyCode, time: timestamp))
        }
    }

    fileprivate func handleOverlayEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if PermissionService.snapshot().accessibilityGranted {
                if let overlayEventTap { CGEvent.tapEnable(tap: overlayEventTap, enable: true) }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.stopOverlayEventTap()
                    self.onPermissionsUnavailable?()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        guard !isSuspended else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp, swallowedKeys.remove(keyCode) != nil {
            return nil
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        if let command = OverlayKeyboardMapping.command(
            for: keyCode,
            flags: event.flags,
            confirmationKey: preferences.windowConfirmationKey
        ),
           onOverlayCommand?(command) == true {
            swallowedKeys.insert(keyCode)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func installHotKeyEventHandler() -> Bool {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userInfo in
                guard let event, let userInfo else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    service.handleHotKeyEvent(event)
                }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyEventHandler
        )
        return status == noErr
    }

    private func refreshHotKeyRegistrations() {
        unregisterHotKeys()
        for (keyCode, bindingID) in bindingIDsByKeyCode.sorted(by: { $0.key < $1.key }) {
            let identifier = UInt32(keyCode) + 1
            let hotKeyID = EventHotKeyID(signature: 0x5748_524C, id: identifier)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                preferences.switchingModifier.carbonHotKeyMask,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else { continue }
            hotKeyReferences[identifier] = reference
            bindingIDsByHotKeyID[identifier] = bindingID
        }
    }

    private func unregisterHotKeys() {
        for reference in hotKeyReferences.values {
            UnregisterEventHotKey(reference)
        }
        hotKeyReferences.removeAll()
        bindingIDsByHotKeyID.removeAll()
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        guard !isSuspended else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, let bindingID = bindingIDsByHotKeyID[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }

        let actions = stateMachine.nonModifierKey(bindingID: bindingID)
        if actions.contains(.launchBinding(bindingID)) {
            perform(actions)
        } else {
            onLaunchBinding?(bindingID)
        }
        return noErr
    }

    private func perform(_ actions: [GestureAction]) {
        for action in actions {
            switch action {
            case .scheduleLongPress(let modifierKeyCode, let delay):
                longPressWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.perform(self.stateMachine.longPressFired(modifierKeyCode: modifierKeyCode))
                }
                longPressWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            case .cancelLongPress:
                longPressWorkItem?.cancel()
                longPressWorkItem = nil
            case .showAppBar:
                onShowAppBar?()
            case .hideAppBar:
                onHideAppBar?()
            case .showWindowBar:
                onShowWindowBar?()
            case .shortTap:
                onShortModifierTap?()
            case .launchBinding(let id):
                onLaunchBinding?(id)
            }
        }
    }
}

private extension SwitchingModifier {
    var carbonHotKeyMask: UInt32 {
        switch self {
        case .option: UInt32(optionKey)
        case .command: UInt32(cmdKey)
        case .shift: UInt32(shiftKey)
        case .control: UInt32(controlKey)
        }
    }

    func isPressed(keyCode: UInt16, in flags: NSEvent.ModifierFlags) -> Bool {
        // NSEvent retains the device-dependent left/right modifier bits from
        // IOLLEvent.h. Reading the changed key's bit makes flagsChanged
        // handling idempotent and keeps both physical modifier keys distinct.
        let deviceMask: NSEvent.ModifierFlags.RawValue
        switch keyCode {
        case 58: deviceMask = 0x0000_0020 // left Option
        case 61: deviceMask = 0x0000_0040 // right Option
        case 55: deviceMask = 0x0000_0008 // left Command
        case 54: deviceMask = 0x0000_0010 // right Command
        case 56: deviceMask = 0x0000_0002 // left Shift
        case 60: deviceMask = 0x0000_0004 // right Shift
        case 59: deviceMask = 0x0000_0001 // left Control
        case 62: deviceMask = 0x0000_2000 // right Control
        default: return false
        }
        return flags.rawValue & deviceMask != 0
    }
}
