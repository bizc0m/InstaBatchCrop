import CoreGraphics
import CoreText
import Foundation
import ImageIO

public struct WatermarkRenderer: Sendable {
    public init() {}

    public func render(on image: CGImage, settings: WatermarkSettings) -> CGImage {
        guard settings.isEnabled,
              settings.imageURL != nil || !settings.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return image
        }
        let width = image.width
        let height = image.height
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }

        let outputRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: outputRect)

        if let logo = loadLogo(from: settings.imageURL) {
            drawLogo(logo, in: context, outputSize: outputRect.size, settings: settings)
        } else {
            drawText(in: context, outputSize: outputRect.size, settings: settings)
        }

        guard let rendered = context.makeImage() else {
            return image
        }
        return rendered
    }

    private func drawText(in context: CGContext, outputSize: CGSize, settings: WatermarkSettings) {
        let substitutedText = substituteVariables(settings.text)
        let font = CTFontCreateWithName("HelveticaNeue-Semibold" as CFString, settings.size, nil)
        let color = CGColor(
            red: min(max(settings.color.red, 0), 1),
            green: min(max(settings.color.green, 0), 1),
            blue: min(max(settings.color.blue, 0), 1),
            alpha: min(max(settings.opacity, 0), 1)
        )
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color
        ]
        let attributed = CFAttributedStringCreate(nil, substitutedText as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(settings.size * 1.25))
        let rect = placementRect(textSize: textSize, outputSize: outputSize, settings: settings)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: CGColor(red: 0, green: 0, blue: 0, alpha: min(0.75, settings.opacity + 0.25)))
        context.textPosition = CGPoint(x: rect.minX, y: rect.minY + max(0, (rect.height - settings.size) / 2))
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawLogo(_ logo: CGImage, in context: CGContext, outputSize: CGSize, settings: WatermarkSettings) {
        let maxSide = max(1, settings.size * 4)
        let logoSize = CGSize(width: logo.width, height: logo.height)
        let scale = min(maxSide / logoSize.width, maxSide / logoSize.height)
        let drawSize = CGSize(width: logoSize.width * scale, height: logoSize.height * scale)
        let rect = placementRect(textSize: drawSize, outputSize: outputSize, settings: settings)
        context.saveGState()
        context.setAlpha(min(max(settings.opacity, 0), 1))
        context.interpolationQuality = .high
        context.clip(to: rect, mask: logo)
        context.setFillColor(CGColor(
            red: min(max(settings.color.red, 0), 1),
            green: min(max(settings.color.green, 0), 1),
            blue: min(max(settings.color.blue, 0), 1),
            alpha: 1
        ))
        context.fill(rect)
        context.restoreGState()
    }

    private func loadLogo(from url: URL?) -> CGImage? {
        guard let url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary)
    }

    public func placementRect(textSize: CGSize, outputSize: CGSize, settings: WatermarkSettings) -> CGRect {
        let margin = max(0, settings.margin)
        let origin: CGPoint = switch settings.position {
        case .bottomRight:
            CGPoint(x: outputSize.width - textSize.width - margin, y: margin)
        case .bottomLeft:
            CGPoint(x: margin, y: margin)
        case .topRight:
            CGPoint(x: outputSize.width - textSize.width - margin, y: outputSize.height - textSize.height - margin)
        case .topLeft:
            CGPoint(x: margin, y: outputSize.height - textSize.height - margin)
        case .center:
            CGPoint(x: (outputSize.width - textSize.width) / 2, y: (outputSize.height - textSize.height) / 2)
        }
        return CGRect(origin: origin, size: textSize)
    }

    private func substituteVariables(_ text: String) -> String {
        var result = text

        // Remplacer les variables dynamiques
        result = result.replacingOccurrences(of: "$date", with: Self.dateString())
        result = result.replacingOccurrences(of: "$time", with: Self.timeString())
        result = result.replacingOccurrences(of: "$datetime", with: Self.dateTimeString())
        result = result.replacingOccurrences(of: "$day", with: Self.dayString())
        result = result.replacingOccurrences(of: "$month", with: Self.monthString())
        result = result.replacingOccurrences(of: "$year", with: Self.yearString())
        result = result.replacingOccurrences(of: "$user", with: Self.userString())
        result = result.replacingOccurrences(of: "$clipboard", with: Self.clipboardString())

        // Remplacer les variables EXIF
        result = result.replacingOccurrences(of: "$EXIF", with: Self.exifString())

        // Remplacer les variables personnalisées
        result = result.replacingOccurrences(of: "$VILLE", with: Self.cityString())
        result = result.replacingOccurrences(of: "$PAYS", with: Self.countryString())

        return result
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    private static func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }

    private static func dayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private static func monthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    private static func yearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private static func userString() -> String {
        return NSUserName()
    }

    private static func clipboardString() -> String {
        guard let pasteboard = NSPasteboard.general.string(forType: .string) else {
            return ""
        }
        return pasteboard
    }

    private static func exifString() -> String {
        // Implémentation simplifiée - dans une vraie implémentation, il faudrait extraire les données EXIF réelles
        return "EXIF_DATA"
    }

    private static func cityString() -> String {
        // Implémentation simplifiée - dans une vraie implémentation, il faudrait utiliser un service de géolocalisation
        return "Ville"
    }

    private static func countryString() -> String {
        // Implémentation simplifiée - dans une vraie implémentation, il faudrait utiliser un service de géolocalisation
        return "Pays"
    }
}
