import AppKit
import Foundation
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - CardRenderer

/// Renders card images from text using Core Graphics (CGContext pipeline).
struct CardRenderer {

    static func render(config: CardConfig) throws -> URL {
        // Create output folder
        let outputDir = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteSnap", isDirectory: true)

        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try FileManager.default.createDirectory(
                at: outputDir, withIntermediateDirectories: true)
        }

        let ts = DateFormatter()
        ts.dateFormat = "yyyyMMdd-HHmmss"
        let url = outputDir.appendingPathComponent("\(ts.string(from: Date())).png")

        // Canvas size
        let cw = config.cardWidth + config.theme.padding * 2
        let ch = config.cardHeight + config.theme.padding * 2
        let sw = cw * config.outputScale
        let sh = ch * config.outputScale

        guard let ctx = CGContext(
            data: nil, width: Int(sw), height: Int(sh),
            bitsPerComponent: 8, bytesPerRow: 4 * Int(sw),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw RenderError.contextFail }

        ctx.translateBy(x: 0, y: sh)
        ctx.scaleBy(x: 1, y: -1)

        // ── 1. background ──
        ctx.setFillColor(hex(config.theme.backgroundColor))
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: sw, height: sh)))

        // ── 2. card with shadow ──
        let pad = config.theme.padding * config.outputScale
        let cr  = config.theme.cornerRadius * config.outputScale
        let card = CGRect(x: pad, y: pad,
                           width: config.cardWidth  * config.outputScale,
                           height: config.cardHeight * config.outputScale)

        ctx.setShadow(offset: CGSize(width: 0, height: 4 * config.outputScale),
                      blur: 16 * config.outputScale,
                      color: CGColor(gray: 0, alpha: 0.12))
        ctx.addRoundedRectPath(card, cr: cr)
        ctx.setFillColor(hex(config.theme.cardBackground))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // ── 3. accent bar ──
        let aw = 48 * config.outputScale
        ctx.addRoundedRectPath(
            CGRect(x: card.midX - aw / 2, y: card.minY + 10 * config.outputScale,
                    width: aw, height: 6 * config.outputScale),
            cr: 3 * config.outputScale)
        ctx.setFillColor(hex(config.theme.accentColor))
        ctx.fillPath()

        // ── 4. text ──
        let tx = card.minX + pad
        let ty = card.minY + 24 * config.outputScale
        let tw = card.width - pad * 2
        let th = card.height - 24 * config.outputScale - pad
        let tRect = CGRect(x: tx, y: ty, width: tw, height: th)

        let font = findFont(config.theme.fontFamily, size: config.theme.fontSize * config.outputScale)
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(cgColor: hex(config.theme.textColor)),
            .font: font,
            .paragraphStyle: ps
        ]
        NSAttributedString(string: config.text, attributes: attrs).draw(in: tRect)

        // ── 5. watermark ──
        let wf = NSFont.systemFont(ofSize: 8 * config.outputScale, weight: .light)
        let wps = NSMutableParagraphStyle()
        wps.alignment = .right
        let wa: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemGray.withAlphaComponent(0.4),
            .font: wf,
            .paragraphStyle: wps
        ]
        let wRect = CGRect(x: sw - 100 * config.outputScale,
                            y: sh - 30 * config.outputScale,
                            width: 80 * config.outputScale, height: 20 * config.outputScale)
        NSAttributedString(string: "PasteSnap", attributes: wa).draw(in: wRect)

        // ── 6. save PNG ──
        guard let img = ctx.makeImage() else { throw RenderError.imageFail }
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw RenderError.encodeFail }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { throw RenderError.encodeFail }

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
        for fb in ["SF Mono", "Menlo", "Courier New"] {
            if let f = NSFont(name: fb, size: size) { return f }
        }
        return NSFont.systemFont(ofSize: size)
    }
}

// MARK: - Errors

enum RenderError: Error {
    case contextFail, imageFail, encodeFail
}

// MARK: - Conveniences

private extension CGContext {
    func addRoundedRectPath(_ r: CGRect, cr: CGFloat) {
        let path = CGMutablePath()
        path.addRoundedRect(in: r, cornerWidth: cr, cornerHeight: cr)
        addPath(path)
    }
}
