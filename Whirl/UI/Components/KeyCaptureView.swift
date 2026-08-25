import AppKit
import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    let focusRequest: Int
    let onCapture: (KeyBinding) -> Void

    init(focusRequest: Int = 0, onCapture: @escaping (KeyBinding) -> Void) {
        self.focusRequest = focusRequest
        self.onCapture = onCapture
    }

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityIdentifier("key.capture")
        view.setAccessibilityLabel(String(localized: "bindings.capture_placeholder"))
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        _ = focusRequest
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyCaptureNSView: NSView {
    var onCapture: ((KeyBinding) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.controlBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = String(localized: "bindings.capture_placeholder") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let binding = KeyBinding.from(keyCode: event.keyCode) else {
            NSSound.beep()
            return
        }
        onCapture?(binding)
    }
}
