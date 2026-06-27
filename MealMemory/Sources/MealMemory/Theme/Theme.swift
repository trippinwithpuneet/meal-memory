import SwiftUI

enum Theme {
    // Palette — Warm Masala (locked in design review)
    static let appBackground  = Color(hex: "#faf8f4")
    static let cardFilled     = Color(hex: "#fff8f0")
    static let cardEmpty      = Color(hex: "#f4f2ee")
    static let navy           = Color(hex: "#1a2744")
    static let saffron        = Color(hex: "#e8883a")
    static let terracotta     = Color(hex: "#c8553a")
    static let textPrimary    = Color(hex: "#1a1a1a")
    static let textSecondary  = Color(hex: "#6b6b6b")
    static let textTertiary   = Color(hex: "#9a9a9a")
    static let border         = Color(hex: "#e8e4de")
    static let danger         = Color(hex: "#d04040")
    static let sage           = Color(hex: "#7a9e7e")

    // Typography
    enum Font {
        static func largeTitle() -> SwiftUI.Font  { .system(size: 32, weight: .bold, design: .default) }
        static func sectionHeader() -> SwiftUI.Font { .system(size: 12, weight: .semibold, design: .default) }
        static func body() -> SwiftUI.Font          { .system(size: 15, weight: .regular, design: .default) }
        static func slotName() -> SwiftUI.Font      { .system(size: 8,  weight: .semibold, design: .default) }
        static func caption() -> SwiftUI.Font       { .system(size: 11, weight: .regular, design: .default) }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
