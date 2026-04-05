import Foundation

// MARK: - CardTheme

/// Card theme preset with colors, typography, and layout parameters.
struct CardTheme: Sendable {
    let identifier: String
    let backgroundColor: String
    let cardBackground: String
    let textColor: String
    let accentColor: String
    let fontFamily: String
    let fontSize: Double
    let fontStyle: String
    let cornerRadius: Double
    let padding: Double
    let maxWidth: Double
    let maxHeight: Double

    // MARK: Presets

    static let darkCode = CardTheme(
        identifier: "dark-code",
        backgroundColor: "#1E1E2E",
        cardBackground: "#313244",
        textColor: "#CDD6F4",
        accentColor: "#89B4FA",
        fontFamily: "SFMono-Regular",
        fontSize: 14,
        fontStyle: "Monospace (code layout)",
        cornerRadius: 10,
        padding: 32,
        maxWidth: 680,
        maxHeight: 400
    )

    static let lightQuote = CardTheme(
        identifier: "light-quote",
        backgroundColor: "#FDFCF8",
        cardBackground: "#FFFFFF",
        textColor: "#1D1D1F",
        accentColor: "#FF6B6B",
        fontFamily: "Noteworthy-Light",
        fontSize: 16,
        fontStyle: "Serif (quote layout)",
        cornerRadius: 16,
        padding: 48,
        maxWidth: 600,
        maxHeight: 420
    )

    static let minimalGray = CardTheme(
        identifier: "minimal-gray",
        backgroundColor: "#F5F5F7",
        cardBackground: "#FFFFFF",
        textColor: "#1D1D1F",
        accentColor: "#636366",
        fontFamily: ".SFProText",
        fontSize: 13,
        fontStyle: "Sans-serif (clean)",
        cornerRadius: 8,
        padding: 24,
        maxWidth: 640,
        maxHeight: 360
    )

    // MARK: Lookup

    static func from(identifier: String) -> CardTheme {
        switch identifier {
        case "dark-code":
            return .darkCode
        case "light-quote":
            return .lightQuote
        case "minimal-gray":
            return .minimalGray
        default:
            return .darkCode
        }
    }

    static let allThemes: [CardTheme] = [.darkCode, .lightQuote, .minimalGray]
}
