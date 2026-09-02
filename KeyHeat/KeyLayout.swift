import CoreGraphics
import Foundation

enum KeyID: String, Codable, CaseIterable, Sendable {
    case escape, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case grave, one, two, three, four, five, six, seven, eight, nine, zero, minus, equal, delete
    case tab, q, w, e, r, t, y, u, i, o, p, leftBracket, rightBracket, backslash
    case capsLock, a, s, d, f, g, h, j, k, l, semicolon, quote, `return`
    case leftShift, z, x, c, v, b, n, m, comma, period, slash, rightShift
    case fn, leftControl, leftOption, leftCommand, space, rightCommand, rightOption
    case leftArrow, downArrow, upArrow, rightArrow
}

enum KeyStyle: Equatable, Sendable {
    case standard
    case untracked
}

struct KeyDefinition: Identifiable, Sendable {
    let id: KeyID?
    let label: String
    let keyCode: CGKeyCode?
    let width: CGFloat
    let style: KeyStyle

    init(
        _ id: KeyID?,
        _ label: String,
        code: CGKeyCode?,
        width: CGFloat = 1,
        style: KeyStyle = .standard
    ) {
        self.id = id
        self.label = label
        self.keyCode = code
        self.width = width
        self.style = style
    }
}

enum KeyLayout {
    static let rows: [[KeyDefinition]] = [
        [
            KeyDefinition(.escape, "esc", code: 53, width: 1.2),
            KeyDefinition(.f1, "F1", code: 122),
            KeyDefinition(.f2, "F2", code: 120),
            KeyDefinition(.f3, "F3", code: 99),
            KeyDefinition(.f4, "F4", code: 118),
            KeyDefinition(.f5, "F5", code: 96),
            KeyDefinition(.f6, "F6", code: 97),
            KeyDefinition(.f7, "F7", code: 98),
            KeyDefinition(.f8, "F8", code: 100),
            KeyDefinition(.f9, "F9", code: 101),
            KeyDefinition(.f10, "F10", code: 109),
            KeyDefinition(.f11, "F11", code: 103),
            KeyDefinition(.f12, "F12", code: 111),
            KeyDefinition(nil, "Touch ID", code: nil, width: 1.2, style: .untracked),
        ],
        [
            KeyDefinition(.grave, "~\n`", code: 50),
            KeyDefinition(.one, "!\n1", code: 18),
            KeyDefinition(.two, "@\n2", code: 19),
            KeyDefinition(.three, "#\n3", code: 20),
            KeyDefinition(.four, "$\n4", code: 21),
            KeyDefinition(.five, "%\n5", code: 23),
            KeyDefinition(.six, "^\n6", code: 22),
            KeyDefinition(.seven, "&\n7", code: 26),
            KeyDefinition(.eight, "*\n8", code: 28),
            KeyDefinition(.nine, "(\n9", code: 25),
            KeyDefinition(.zero, ")\n0", code: 29),
            KeyDefinition(.minus, "_\n-", code: 27),
            KeyDefinition(.equal, "+\n=", code: 24),
            KeyDefinition(.delete, "delete", code: 51, width: 1.65),
        ],
        [
            KeyDefinition(.tab, "tab", code: 48, width: 1.5),
            KeyDefinition(.q, "Q", code: 12),
            KeyDefinition(.w, "W", code: 13),
            KeyDefinition(.e, "E", code: 14),
            KeyDefinition(.r, "R", code: 15),
            KeyDefinition(.t, "T", code: 17),
            KeyDefinition(.y, "Y", code: 16),
            KeyDefinition(.u, "U", code: 32),
            KeyDefinition(.i, "I", code: 34),
            KeyDefinition(.o, "O", code: 31),
            KeyDefinition(.p, "P", code: 35),
            KeyDefinition(.leftBracket, "{\n[", code: 33),
            KeyDefinition(.rightBracket, "}\n]", code: 30),
            KeyDefinition(.backslash, "|\n\\", code: 42, width: 1.5),
        ],
        [
            KeyDefinition(.capsLock, "caps lock", code: 57, width: 1.75),
            KeyDefinition(.a, "A", code: 0),
            KeyDefinition(.s, "S", code: 1),
            KeyDefinition(.d, "D", code: 2),
            KeyDefinition(.f, "F", code: 3),
            KeyDefinition(.g, "G", code: 5),
            KeyDefinition(.h, "H", code: 4),
            KeyDefinition(.j, "J", code: 38),
            KeyDefinition(.k, "K", code: 40),
            KeyDefinition(.l, "L", code: 37),
            KeyDefinition(.semicolon, ":\n;", code: 41),
            KeyDefinition(.quote, "\"\n'", code: 39),
            KeyDefinition(.return, "return", code: 36, width: 1.75),
        ],
        [
            KeyDefinition(.leftShift, "⇧", code: 56, width: 2.25),
            KeyDefinition(.z, "Z", code: 6),
            KeyDefinition(.x, "X", code: 7),
            KeyDefinition(.c, "C", code: 8),
            KeyDefinition(.v, "V", code: 9),
            KeyDefinition(.b, "B", code: 11),
            KeyDefinition(.n, "N", code: 45),
            KeyDefinition(.m, "M", code: 46),
            KeyDefinition(.comma, "<\n,", code: 43),
            KeyDefinition(.period, ">\n.", code: 47),
            KeyDefinition(.slash, "?\n/", code: 44),
            KeyDefinition(.rightShift, "⇧", code: 60, width: 2.25),
        ],
        [
            KeyDefinition(.fn, "fn", code: 63),
            KeyDefinition(.leftControl, "⌃", code: 59),
            KeyDefinition(.leftOption, "⌥", code: 58),
            KeyDefinition(.leftCommand, "⌘", code: 55, width: 1.25),
            KeyDefinition(.space, "", code: 49, width: 5),
            KeyDefinition(.rightCommand, "⌘", code: 54, width: 1.25),
            KeyDefinition(.rightOption, "⌥", code: 61),
            KeyDefinition(.leftArrow, "◀", code: 123),
            KeyDefinition(.downArrow, "▼", code: 125, width: 0.5),
            KeyDefinition(.upArrow, "▲", code: 126, width: 0.5),
            KeyDefinition(.rightArrow, "▶", code: 124),
        ],
    ]

    static let keyByCode: [CGKeyCode: KeyID] = Dictionary(
        uniqueKeysWithValues: rows
            .flatMap { $0 }
            .compactMap { definition in
                guard let keyCode = definition.keyCode, let id = definition.id else { return nil }
                return (keyCode, id)
            }
    )

    static let definitionByID: [KeyID: KeyDefinition] = Dictionary(
        uniqueKeysWithValues: rows
            .flatMap { $0 }
            .compactMap { definition in
                guard let id = definition.id else { return nil }
                return (id, definition)
            }
    )
}
