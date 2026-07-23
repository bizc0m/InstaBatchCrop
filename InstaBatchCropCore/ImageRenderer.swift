import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct RenderedImage {
    public var image: CGImage
    public var metadata: [String: Any]

    public init(image: CGImage, metadata: [String: Any]) {
        self.image = image
        self.metadata = metadata
    }
}

public struct ImageRenderer: Sendable {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let watermarkRenderer = WatermarkRenderer()

    public init() {}

    public func render(
        inputURL: URL,
        target: OutputFormat,
        decision: CropDecision,
        observations: [SubjectObservation],
        settings: CropSettings
    ) throws -> RenderedImage {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let ciImage = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true]) else {
            throw ProcessingError.cannotReadImage(inputURL)
        }

        let metadata = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        let outputSize = target.pixelSize
        let outputExtent = CGRect(origin: .zero, size: outputSize)
        let sourceExtent = ciImage.extent
        let sourceHeight = sourceExtent.height
        let ciCropRect = CGRect(
            x: decision.cropRect.minX,
            y: sourceHeight - decision.cropRect.maxY,
            width: decision.cropRect.width,
            height: decision.cropRect.height
        ).intersection(sourceExtent)

        let result: CIImage
        if decision.usesFallback {
            result = fallbackImage(ciImage: ciImage, outputExtent: outputExtent, settings: settings)
        } else {
            let cropped = ciImage.cropped(to: ciCropRect)
            result = scaleToFill(cropped, outputExtent: outputExtent)
        }

        let final = settings.debugOverlay ? drawDebugOverlay(
            on: result,
            outputExtent: outputExtent,
            decision: decision,
            observations: observations,
            sourceExtent: sourceExtent,
            cropRect: decision.usesFallback ? sourceExtent : decision.cropRect
        ) : result

        guard let cgImage = context.createCGImage(final, from: outputExtent) else {
            throw ProcessingError.cannotRender(inputURL)
        }
        let watermarked = watermarkRenderer.render(on: cgImage, settings: settings.watermark)
        return RenderedImage(image: watermarked, metadata: metadata)
    }

    public func write(_ rendered: RenderedImage, to outputURL: URL, settings: CropSettings) throws {
        let type = settings.exportType.uniformType
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, type.identifier as CFString, 1, nil) else {
            throw ProcessingError.cannotWrite(outputURL)
        }

        var options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: settings.jpegQuality
        ]
        if settings.preserveMetadata {
            options[kCGImagePropertyExifDictionary] = rendered.metadata[kCGImagePropertyExifDictionary as String]
            options[kCGImagePropertyTIFFDictionary] = rendered.metadata[kCGImagePropertyTIFFDictionary as String]
        }
        CGImageDestinationAddImage(destination, rendered.image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.cannotWrite(outputURL)
        }
    }

    private func scaleToFill(_ image: CIImage, outputExtent: CGRect) -> CIImage {
        let scale = max(outputExtent.width / image.extent.width, outputExtent.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let translated = scaled.transformed(by: CGAffineTransform(
            translationX: outputExtent.midX - scaled.extent.midX,
            y: outputExtent.midY - scaled.extent.midY
        ))
        return translated.cropped(to: outputExtent)
    }

    private func scaleToFit(_ image: CIImage, outputExtent: CGRect) -> CIImage {
        let scale = min(outputExtent.width / image.extent.width, outputExtent.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled.transformed(by: CGAffineTransform(
            translationX: outputExtent.midX - scaled.extent.midX,
            y: outputExtent.midY - scaled.extent.midY
        ))
    }

    private func fallbackImage(ciImage: CIImage, outputExtent: CGRect, settings: CropSettings) -> CIImage {
        let fitted = scaleToFit(ciImage, outputExtent: outputExtent)
        switch settings.fallbackMode {
        case .solidBackground:
            let background = CIImage(color: .init(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)).cropped(to: outputExtent)
            return fitted.composited(over: background)
        case .keepWholeImage, .blurredBackground:
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = scaleToFill(ciImage, outputExtent: outputExtent)
            blur.radius = 28
            let background = (blur.outputImage ?? scaleToFill(ciImage, outputExtent: outputExtent)).cropped(to: outputExtent)
            return fitted.composited(over: background)
        case .maximumCrop:
            return scaleToFill(ciImage, outputExtent: outputExtent)
        }
    }

    private func drawDebugOverlay(
        on image: CIImage,
        outputExtent: CGRect,
        decision: CropDecision,
        observations: [SubjectObservation],
        sourceExtent: CGRect,
        cropRect: CGRect
    ) -> CIImage {
        let nsImage = NSImage(size: outputExtent.size)
        nsImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: context.createCGImage(image, from: outputExtent)!, size: outputExtent.size)
            .draw(in: outputExtent)
        NSColor.systemGreen.setStroke()
        draw(rect: map(decision.subjectRect, from: cropRect, to: outputExtent), lineWidth: 4)
        NSColor.systemRed.setStroke()
        observations.forEach { draw(rect: map($0.rect, from: cropRect, to: outputExtent), lineWidth: 2) }
        nsImage.unlockFocus()
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else {
            return image
        }
        return CIImage(cgImage: cg)
    }

    private func draw(rect: CGRect, lineWidth: CGFloat) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func map(_ rect: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let x = (rect.minX - source.minX) / source.width * target.width
        let y = (rect.minY - source.minY) / source.height * target.height
        return CGRect(x: x, y: y, width: rect.width / source.width * target.width, height: rect.height / source.height * target.height)
    }
}

extension ExportFileType {
    var uniformType: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .webp: .webP
        }
    }
}
