import AppKit
import Foundation

struct KeyBinding: Codable, Hashable, Identifiable, Sendable {
    let keyCode: UInt16
    let label: String

    var id: UInt16 { keyCode }

    func displayText(modifier: SwitchingModifier) -> String {
        "\(modifier.symbol) + \(label)"
    }

    static func from(keyCode: UInt16) -> KeyBinding? {
        guard let label = allowedKeyLabels[keyCode] else { return nil }
        return KeyBinding(keyCode: keyCode, label: label)
    }

    static let allowedKeyLabels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
        6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O",
        32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
        45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9", 29: "0"
    ]

    static func digit(for keyCode: UInt16) -> Int? {
        let numberRow: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9, 29: 0]
        let keypad: [UInt16: Int] = [83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9, 82: 0]
        return numberRow[keyCode] ?? keypad[keyCode]
    }
}
