import Foundation
import Testing
@testable import Whirl

struct ModifierGestureStateMachineTests {
    private let preferences = AppPreferences(
        switchingModifier: .command,
        longPressDuration: 0.4,
        doubleTapInterval: 0.3,
        animationDuration: 1,
        applicationOverlayVerticalPosition: 0
    )

    @Test func ignoresUnselectedModifier() {
        var machine = ModifierGestureStateMachine()
        #expect(machine.modifierDown(keyCode: 58, time: 1, preferences: preferences).isEmpty)
        #expect(machine.pressedModifierKeyCode == nil)
    }

    @Test func acceptsEitherPhysicalKeyForSelectedModifier() {
        var machine = ModifierGestureStateMachine()
        #expect(machine.modifierDown(keyCode: 54, time: 1, preferences: preferences) == [
            .scheduleLongPress(modifierKeyCode: 54, delay: 0.4)
        ])
    }

    @Test func longPressShowsAndReleaseHidesAppBar() {
        var machine = ModifierGestureStateMachine()
        #expect(machine.modifierDown(keyCode: 55, time: 1, preferences: preferences) == [
            .scheduleLongPress(modifierKeyCode: 55, delay: 0.4)
        ])
        #expect(machine.longPressFired(modifierKeyCode: 55) == [.showAppBar])
        #expect(machine.modifierUp(keyCode: 55, time: 1.6) == [.cancelLongPress, .hideAppBar])
    }

    @Test func twoShortTapsShowWindowBar() {
        var machine = ModifierGestureStateMachine()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        #expect(machine.modifierUp(keyCode: 55, time: 1.05) == [.cancelLongPress, .shortTap])
        _ = machine.modifierDown(keyCode: 55, time: 1.2, preferences: preferences)
        #expect(machine.modifierUp(keyCode: 55, time: 1.25) == [.cancelLongPress, .showWindowBar])
    }

    @Test func shortTapAfterWindowBarRequestsDismissal() {
        var machine = ModifierGestureStateMachine()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        _ = machine.modifierUp(keyCode: 55, time: 1.05)
        _ = machine.modifierDown(keyCode: 55, time: 1.2, preferences: preferences)
        _ = machine.modifierUp(keyCode: 55, time: 1.25)

        _ = machine.modifierDown(keyCode: 55, time: 1.7, preferences: preferences)
        #expect(machine.modifierUp(keyCode: 55, time: 1.75) == [.cancelLongPress, .shortTap])
    }

    @Test func slowSecondTapDoesNotShowWindowBar() {
        var machine = ModifierGestureStateMachine()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        _ = machine.modifierUp(keyCode: 55, time: 1.05)
        _ = machine.modifierDown(keyCode: 55, time: 1.5, preferences: preferences)
        #expect(machine.modifierUp(keyCode: 55, time: 1.55) == [.cancelLongPress, .shortTap])
    }

    @Test func boundChordCancelsGesturesAndLaunches() {
        var machine = ModifierGestureStateMachine()
        let id = UUID()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        #expect(machine.nonModifierKey(bindingID: id) == [.cancelLongPress, .launchBinding(id)])
        #expect(machine.modifierUp(keyCode: 55, time: 1.1) == [.cancelLongPress])
    }

    @Test func boundChordWinsDuringSecondTap() {
        var machine = ModifierGestureStateMachine()
        let id = UUID()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        _ = machine.modifierUp(keyCode: 55, time: 1.05)
        _ = machine.modifierDown(keyCode: 55, time: 1.2, preferences: preferences)
        #expect(machine.nonModifierKey(bindingID: id) == [.cancelLongPress, .launchBinding(id)])
        #expect(machine.modifierUp(keyCode: 55, time: 1.25) == [.cancelLongPress])
    }

    @Test func longPressWinsDuringSecondTap() {
        var machine = ModifierGestureStateMachine()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        _ = machine.modifierUp(keyCode: 55, time: 1.05)
        _ = machine.modifierDown(keyCode: 55, time: 1.2, preferences: preferences)
        #expect(machine.longPressFired(modifierKeyCode: 55) == [.showAppBar])
        #expect(machine.modifierUp(keyCode: 55, time: 1.7) == [.cancelLongPress, .hideAppBar])
    }

    @Test func unboundChordCancelsGestureWithoutAction() {
        var machine = ModifierGestureStateMachine()
        _ = machine.modifierDown(keyCode: 55, time: 1, preferences: preferences)
        #expect(machine.nonModifierKey(bindingID: nil) == [.cancelLongPress])
        #expect(machine.modifierUp(keyCode: 55, time: 1.1) == [.cancelLongPress])
    }
}
