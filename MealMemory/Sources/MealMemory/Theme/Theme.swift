import SwiftUI
import UIKit

// Appearance the user picks in Settings. `system` follows the device.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum Theme {
    // Palette — Warm Masala. Each token is an adaptive light/dark pair; the
    // dark side was approved in the dark-mode palette review.
    static let appBackground  = Color(light: "#faf8f4", dark: "#16130F")
    static let cardFilled     = Color(light: "#fff8f0", dark: "#23201A")
    static let cardEmpty      = Color(light: "#f4f2ee", dark: "#1E1B15")
    static let navy           = Color(light: "#1a2744", dark: "#ECE7DC")  // used mostly as heading TEXT → off-white in dark
    static let saffron        = Color(light: "#e8883a", dark: "#D2914A")
    static let terracotta     = Color(light: "#c8553a", dark: "#CD6E50")
    static let textPrimary    = Color(light: "#1a1a1a", dark: "#ECE7DC")
    static let textSecondary  = Color(light: "#6b6b6b", dark: "#A69E90")
    static let textTertiary   = Color(light: "#9a9a9a", dark: "#7A7468")
    static let border         = Color(light: "#e8e4de", dark: "#332E26")
    static let danger         = Color(light: "#d04040", dark: "#E05A5A")
    static let sage           = Color(light: "#7a9e7e", dark: "#86A06F")
    // Navy used as a SURFACE/background (white text sits on it) — stays dark in
    // both modes so that content remains legible.
    static let brandNavy      = Color(light: "#1a2744", dark: "#1a2744")

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
    // Resolves to `light` or `dark` based on the active interface style.
    init(light: String, dark: String) {
        self = Color(UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? Color(hex: dark) : Color(hex: light))
        })
    }

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
