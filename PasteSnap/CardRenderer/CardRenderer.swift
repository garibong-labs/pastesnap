import AppKit
import Foundation
import CoreGraphics

/// Renders card images from text using Core Graphics (CGContext pipeline).
/// Thread-safe: can be called from background queues.
struct CardRenderer {

    // MARK: Public

    /// Renders a card image and saves it as PNG.
    /// - Returns: The file URL of the saved image.
    static func render(config: CardConfig) throws -> URL {
        // Ensure output directory exists
        let outputDir = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("PasteSnap", isDirectory: true)

        if !outputDir.hasDirectoryPath {
            try FileManager.default.createDirectory(
                at: outputDir,
                withIntermediateDirectories: true
            )
        }

        // Generate unique filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileURL = outputDir.appendingPathComponent("\(timestamp).png")

        // Calculate image size (full canvas with background)
        let canvasWidth = config.cardWidth + config.theme.padding * 2
        let canvasHeight = config.cardHeight + config.theme.padding * 2
        let scaledWidth = canvasWidth * config.outputScale
        let scaledHeight = canvasHeight * config.outputScale

        // Create bitmap context
        let bitsPerComponent = 8
        let bytesPerRow = 4 * Int(scaledWidth)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: Int(scaledWidth),
            height: Int(scaledHeight),
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderError.contextCreationFailed
        }

        // Flip coordinate system for standard top-down drawing
        context.translateBy(x: 0, y: scaledHeight)
        context.scaleBy(x: 1, y: -1)

        // 1. Draw outer background
        guard let bgNSColor = NSColorFactory.from(hexString: config.theme.backgroundColor) else {
            throw RenderError.invalidColor(config.theme.backgroundColor)
        }
        bgNSColor.setFill()
        context.fill(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        // 2. Draw card with drop shadow
        let cardRect = CGRect(
            x: config.theme.padding * config.outputScale,
            y: config.theme.padding * config.outputScale,
            width: config.cardWidth * config.outputScale,
            height: config.cardHeight * config.outputScale
        )
        let cornerRadius = config.theme.cornerRadius * config.outputScale

        drawShadow(context: context, rect: cardRect, cornerRadius: cornerRadius, scale: config.outputScale)

        // 3. Draw card background
        guard let cardNSColor = NSColorFactory.from(hexString: config.theme.cardBackground) else {
            throw RenderError.invalidColor(config.theme.cardBackground)
        }
        cardNSColor.setFill()
        let cardPath = CGRoundedRect(rect: cardRect, cornerRadius: cornerRadius)
        context.addPath(cardPath)
        context.fillPath()

        // 4. Draw accent bar at top
        drawAccentBar(
            context: context,
            cardRect: cardRect,
            accentColor: config.theme.accentColor,
            scale: config.outputScale,
            cornerRadius: cornerRadius
        )

        // 5. Render text
        let textRect = CGRect(
            x: cardRect.origin.x + config.theme.padding * config.outputScale,
            y: cardRect.origin.y + (12 * config.outputScale) + config.theme.padding * config.outputScale,
            width: cardRect.size.width - (config.theme.padding * 2 * config.outputScale),
            height: cardRect.size.height - (12 * config.outputScale) - (config.theme.padding * 3 * config.outputScale)
        )
        renderText(
            context: context,
            text: config.text,
            in: textRect,
            theme: config.theme,
            scale: config.outputScale
        )

        // 6. Draw watermark
        drawWatermark(
            context: context,
            canvasWidth: scaledWidth,
            canvasHeight: scaledHeight,
            scale: config.outputScale
        )

        // 7. Save as PNG
        guard let cgImage = context.makeImage() else {
            throw RenderError.imageCreationFailed
        }
        let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: scaledWidth, height: scaledHeight))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 0.9]) else {
            throw RenderError.encodingFailed
        }
        try pngData.write(to: fileURL)

        return fileURL
    }

    // MARK: Private Drawing Helpers

    private static func drawShadow(
        context: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        scale: CGFloat
    ) {
        let shadowOffset = CGSize(width: 0, height: 4 * scale)
        let shadowBlur = 16 * scale
        let shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor

        context.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)

        let path = CGRoundedRect(rect: rect, cornerRadius: cornerRadius)
        context.addPath(path)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()

        // Reset shadow
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }

    private static func drawAccentBar(
        context: CGContext,
        cardRect: CGRect,
        accentColor: String,
        scale: CGFloat,
        cornerRadius: CGFloat
    ) {
        guard let accentNSColor = NSColorFactory.from(hexString: accentColor) else { return }

        let barHeight = 6 * scale
        let barWidth = 48 * scale
        let barX = cardRect.origin.x + (cardRect.size.width - barWidth) / 2
        let barY = cardRect.origin.y + (12 * scale) - (barHeight / 2)

        let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: cornerRadius / 2, cornerHeight: cornerRadius / 2, transform: nil)

        context.setFillColor(accentNSColor.cgColor)
        context.addPath(barPath)
        context.fillPath()
    }

    private static func renderText(
        context: CGContext,
        text: String,
        in rect: CGRect,
        theme: CardTheme,
        scale: CGFloat
    ) {
        guard let textColor = NSColorFactory.from(hexString: theme.textColor) else { return }

        // Find a valid font (fallback chain)
        let font = findFont(name: theme.fontFamily, size: theme.fontSize * scale)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .natural
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Draw text in context
        let textRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
        attributedString.draw(in: textRect)
    }

    private static func findFont(name: String, size: CGFloat) -> NSFont {
        // System font shortcuts
        if name.starts(with: "."), size > 0 {
            return NSFont.systemFont(ofSize: size, weight: .regular)
        }
        if let font = NSFont(name: name, size: size) {
            return font
        }

        // Fallback chain
        let fallbacks = ["SF Mono", "Menlo", "Courier New", ".SFNS-Regular"]
        for fallback in fallbacks {
            if let font = NSFont(name: fallback, size: size) {
                return font
            }
        }
        return NSFont.systemFont(ofSize: size)
    }

    private static func drawWatermark(
        context: CGContext,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        scale: CGFloat
    ) {
        let font = NSFont.systemFont(ofSize: 8 * scale, weight: .light)
        let textColor = NSColor.systemGray.withAlphaComponent(0.4)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]

        let watermarkText = NSAttributedString(
            string: "PasteSnap",
            attributes: attributes
        )
        let textRect = CGRect(
            x: canvasWidth - (100 * scale),
            y: canvasHeight - (30 * scale),
            width: 80 * scale,
            height: 20 * scale
        )
        watermarkText.draw(in: textRect)
    }
}

// MARK: - Errors

enum RenderError: LocalizedError {
    case contextCreationFailed
    case invalidColor(String)
    case imageCreationFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .contextCreationFailed: return "Failed to create graphics context"
        case let .invalidColor(hex): return "Invalid color: \(hex)"
        case .imageCreationFailed: return "Failed to create CGImage"
        case .encodingFailed: return "Failed to encode image as PNG"
        }
    }
}

// MARK: - NSColor Factory

enum NSColorFactory {
    /// Create a color from a hex string like "#1E1E2E" or "1E1E2E".
    static func from(hexString: String) -> NSColor? {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let rgb = UInt64(hex, radix: 16) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

private func CGRoundedRect(rect: CGRect, cornerRadius: CGFloat) -> CGMutablePath {
    let path = CGMutablePath()
    path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
    return path
}
