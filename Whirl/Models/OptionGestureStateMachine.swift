import Foundation

enum GestureAction: Equatable, Sendable {
    case scheduleLongPress(modifierKeyCode: UInt16, delay: Double)
    case cancelLongPress
    case showAppBar
    case hideAppBar
    case showWindowBar
    case shortTap
    case launchBinding(UUID)
}

struct ModifierGestureStateMachine: Sendable {
    private(set) var pressedModifierKeyCode: UInt16?
    private(set) var lastShortTapTime: TimeInterval?
    private(set) var secondTapCandidate = false
    private(set) var chordUsed = false
    private(set) var appBarVisible = false

    mutating func modifierDown(
        keyCode: UInt16,
        time: TimeInterval,
        preferences: AppPreferences
    ) -> [GestureAction] {
        guard pressedModifierKeyCode == nil,
              preferences.switchingModifier.accepts(keyCode: keyCode) else { return [] }

        pressedModifierKeyCode = keyCode
        chordUsed = false
        appBarVisible = false
        secondTapCandidate = lastShortTapTime.map { time - $0 <= preferences.doubleTapInterval } ?? false
        return [.scheduleLongPress(modifierKeyCode: keyCode, delay: preferences.longPressDuration)]
    }

    mutating func nonModifierKey(bindingID: UUID?) -> [GestureAction] {
        guard pressedModifierKeyCode != nil else { return [] }
        chordUsed = true
        secondTapCandidate = false
        lastShortTapTime = nil
        var actions: [GestureAction] = [.cancelLongPress]
        if appBarVisible {
            appBarVisible = false
            actions.append(.hideAppBar)
        }
        if let bindingID {
            actions.append(.launchBinding(bindingID))
        }
        return actions
    }

    mutating func longPressFired(modifierKeyCode: UInt16) -> [GestureAction] {
        guard pressedModifierKeyCode == modifierKeyCode, !chordUsed else { return [] }
        secondTapCandidate = false
        lastShortTapTime = nil
        appBarVisible = true
        return [.showAppBar]
    }

    mutating func modifierUp(keyCode: UInt16, time: TimeInterval) -> [GestureAction] {
        guard pressedModifierKeyCode == keyCode else { return [] }
        pressedModifierKeyCode = nil
        var actions: [GestureAction] = [.cancelLongPress]

        if appBarVisible {
            appBarVisible = false
            actions.append(.hideAppBar)
        } else if chordUsed {
            chordUsed = false
        } else if secondTapCandidate {
            secondTapCandidate = false
            lastShortTapTime = nil
            actions.append(.showWindowBar)
        } else {
            lastShortTapTime = time
            actions.append(.shortTap)
        }
        return actions
    }

    mutating func reset() -> [GestureAction] {
        let shouldHide = appBarVisible
        self = ModifierGestureStateMachine()
        return shouldHide ? [.cancelLongPress, .hideAppBar] : [.cancelLongPress]
    }
}
