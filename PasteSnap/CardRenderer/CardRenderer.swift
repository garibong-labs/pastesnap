import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct CardRenderer {

    static func render(config: CardConfig) throws -> URL {
        let outputDir = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteSnap", isDirectory: true)

        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        let ts = DateFormatter()
        ts.dateFormat = "yyyyMMdd-HHmmss"
        let url = outputDir.appendingPathComponent("\(ts.string(from: Date())).png")

        let cw = config.cardWidth
        let ch = config.cardHeight
        let s  = config.outputScale

        // ── Render in point space, NSImage handles resolution ──
        let cardImage = NSImage(size: NSSize(width: cw, height: ch), flipped: true) { bounds in
            let pad = config.theme.padding
            let cr = config.theme.cornerRadius
            let card = CGRect(x: pad, y: pad, width: cw - pad * 2, height: ch - pad * 2)
            let ctx = NSGraphicsContext.current!.cgContext

            // 1. outer background
            ctx.setFillColor(hex(config.theme.backgroundColor))
            ctx.fill(bounds)

            // 2. card + shadow
            ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 16,
                          color: CGColor(gray: 0, alpha: 0.12))
            let cardPath = CGMutablePath()
            cardPath.addRoundedRect(in: card, cornerWidth: cr, cornerHeight: cr)
            ctx.addPath(cardPath)
            ctx.setFillColor(hex(config.theme.cardBackground))
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // 3. accent bar
            let aw: CGFloat = 48
            let accentPath = CGMutablePath()
            accentPath.addRoundedRect(
                in: CGRect(x: card.midX - aw / 2, y: card.minY + 12, width: aw, height: 6),
                cornerWidth: 3, cornerHeight: 3)
            ctx.addPath(accentPath)
            ctx.setFillColor(hex(config.theme.accentColor))
            ctx.fillPath()

            // 4. text
            let textPad: CGFloat = 28
            let textRect = CGRect(
                x: card.minX + textPad,
                y: card.minY + 28,
                width: card.width - textPad * 2,
                height: card.height - 28 - textPad
            )

            let font = findFont(config.theme.fontFamily, size: config.theme.fontSize)
            let ps = NSMutableParagraphStyle()
            ps.lineBreakMode = .byWordWrapping
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(cgColor: hex(config.theme.textColor)),
                .font: font,
                .paragraphStyle: ps
            ]
            let attributed = NSAttributedString(string: config.text, attributes: attrs)

            // Measure to center vertically if shorter than card
            let textSize = attributed.boundingRect(
                with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin).size

            var finalRect = textRect
            if textSize.height < textRect.height {
                finalRect.origin.y += (textRect.height - textSize.height) / 2
                finalRect.size.height = textSize.height
            }
            attributed.draw(in: finalRect)

            // 5. watermark
            let wf = NSFont.systemFont(ofSize: 8, weight: .light)
            let wps = NSMutableParagraphStyle()
            wps.alignment = .right
            NSAttributedString(
                string: "PasteSnap",
                attributes: [.foregroundColor: NSColor.systemGray.withAlphaComponent(0.4),
                             .font: wf,
                             .paragraphStyle: wps]
            ).draw(in: CGRect(x: cw - 100, y: ch - 30, width: 80, height: 20))

            return true
        }

        // ── Export PNG at @2x (scale is applied via bestRepresentationFor) ──
        let pixelSize = NSSize(width: cw * s, height: ch * s)
        guard let rep = cardImage.bestRepresentation(for: NSRect(origin: .zero, size: pixelSize),
                                                      context: nil,
                                                      hints: [.ctm: AffineTransform(scale: s)]) else {
            throw RenderError.imageFail
        }

        let tmpImage = NSImage(size: pixelSize)
        tmpImage.lockFocus()
        rep.draw(in: NSRect(origin: .zero, size: pixelSize))
        tmpImage.unlockFocus()

        guard let tiff = tmpImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw RenderError.encodeFail
        }
        let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.9])!
        try png.write(to: url)
        NSLog("[PasteSnap] ✅ Card saved: \(url.path)")
        return url
    }

    // ——— helpers ———

    private static func hex(_ s: String) -> CGColor {
        var h = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard let v = UInt64(h, radix: 16) else { return CGColor.white }
        return CGColor(
            red:   CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8)  & 0xFF) / 255,
            blue:  CGFloat(v & 0xFF) / 255,
            alpha: 1)
    }

    private static func findFont(_ name: String, size: CGFloat) -> NSFont {
        if let f = NSFont(name: name, size: size) { return f }
        for fb in ["SF Mono", "Menlo", "Monaco", "Courier New"] {
            if let f = NSFont(name: fb, size: size) { return f }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

enum RenderError: Error { case contextFail, imageFail, encodeFail }
