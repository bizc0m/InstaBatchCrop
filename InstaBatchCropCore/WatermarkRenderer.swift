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
        let attributed = CFAttributedStringCreate(nil, settings.text as CFString, attributes as CFDictionary)!
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
}
