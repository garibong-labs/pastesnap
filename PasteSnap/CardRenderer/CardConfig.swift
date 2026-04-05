import Foundation

/// Input configuration for card rendering.
struct CardConfig: Sendable {
    let text: String
    let theme: CardTheme
    let cardWidth: Double
    let cardHeight: Double
    let outputScale: Double

    init(text: String, theme: CardTheme, cardWidth: Double? = nil, cardHeight: Double? = nil, outputScale: Double = 2.0) {
        self.text = String(text.prefix(2000))
        self.theme = theme
        self.cardWidth = cardWidth ?? theme.maxWidth
        self.cardHeight = cardHeight ?? theme.maxHeight
        self.outputScale = outputScale
    }
}
