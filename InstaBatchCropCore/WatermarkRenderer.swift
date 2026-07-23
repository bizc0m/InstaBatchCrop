import AppKit
import CoreImage
import Foundation

public struct WatermarkRenderer: Sendable {
    public init() {}

    public func render(on image: CIImage, outputExtent: CGRect, settings: WatermarkSettings) -> CIImage {
        guard settings.isEnabled, !settings.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return image
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let base = context.createCGImage(image, from: outputExtent) else {
            return image
        }

        let nsImage = NSImage(size: outputExtent.size)
        nsImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: base, size: outputExtent.size).draw(in: outputExtent)

        let font = NSFont.systemFont(ofSize: settings.size, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(settings.opacity),
            .paragraphStyle: paragraph,
            .shadow: shadow(opacity: settings.opacity)
        ]
        let attributed = NSAttributedString(string: settings.text, attributes: attributes)
        let textSize = attributed.size()
        let rect = placementRect(textSize: textSize, outputSize: outputExtent.size, settings: settings)
        attributed.draw(in: rect)

        nsImage.unlockFocus()
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else {
            return image
        }
        return CIImage(cgImage: cg)
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

    private func shadow(opacity: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(min(0.7, opacity + 0.25))
        return shadow
    }
}
