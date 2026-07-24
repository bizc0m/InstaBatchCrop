import AppKit
import ImageIO
import Testing
@testable import InstaBatchCropCore

@Suite("BatchProcessor")
struct BatchProcessorTests {
    @Test func rendersSyntheticImagesInBatch() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let input = temp.appendingPathComponent("input", isDirectory: true)
        let output = temp.appendingPathComponent("output", isDirectory: true)
        let plainOutput = temp.appendingPathComponent("plain-output", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plainOutput, withIntermediateDirectories: true)

        let first = input.appendingPathComponent("person_one.jpg")
        let second = input.appendingPathComponent("person_two.jpg")
        try Self.makeSyntheticImage(url: first, size: CGSize(width: 1200, height: 800), rect: CGRect(x: 500, y: 160, width: 240, height: 440))
        try Self.makeSyntheticImage(url: second, size: CGSize(width: 900, height: 1400), rect: CGRect(x: 260, y: 300, width: 300, height: 650))

        let processor = BatchProcessor()
        let results = await processor.process(
            urls: [first, second],
            formats: [.portrait4x5, .square],
            outputDirectory: output,
            settings: CropSettings(
                mode: .natural,
                fallbackMode: .blurredBackground,
                margin: 0.14,
                jpegQuality: 0.92,
                preserveMetadata: false,
                exportType: .jpeg,
                debugOverlay: false,
                qualityThreshold: 0.62,
                watermark: WatermarkSettings(isEnabled: true, text: "TEST", position: .bottomRight, opacity: 0.6, size: 36, margin: 24)
            )
        ) { _, _ in }

        #expect(results.count == 4)
        #expect(results.allSatisfy { $0.outputURL != nil && FileManager.default.fileExists(atPath: $0.outputURL!.path) })
        let portrait = output.appendingPathComponent("person_one_4x5.jpg")
        #expect(Self.pixelSize(portrait) == CGSize(width: 1080, height: 1350))

        _ = await processor.process(
            urls: [first],
            formats: [.portrait4x5],
            outputDirectory: plainOutput,
            settings: CropSettings(
                mode: .natural,
                fallbackMode: .blurredBackground,
                margin: 0.14,
                jpegQuality: 0.92,
                preserveMetadata: false,
                exportType: .jpeg,
                debugOverlay: false,
                qualityThreshold: 0.62
            )
        ) { _, _ in }
        let plainPortrait = plainOutput.appendingPathComponent("person_one_4x5.jpg")
        #expect(Self.pixelDifferenceCount(portrait, plainPortrait) > 100)
    }

    private static func makeSyntheticImage(url: URL, size: CGSize, rect: CGRect) throws {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        CGRect(origin: .zero, size: size).fill()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 60, yRadius: 60).fill()
        NSColor.brown.setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX - 55, y: rect.minY + 30, width: 110, height: 110)).fill()
        image.unlockFocus()
        guard let data = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: data),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw ProcessingError.cannotRender(url)
        }
        try jpeg.write(to: url)
    }

    private static func pixelSize(_ url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    private static func pixelDifferenceCount(_ firstURL: URL, _ secondURL: URL) -> Int {
        guard let first = NSImage(contentsOf: firstURL),
              let second = NSImage(contentsOf: secondURL),
              let firstRep = first.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)),
              let secondRep = second.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)) else {
            return 0
        }
        let width = min(firstRep.pixelsWide, secondRep.pixelsWide)
        let height = min(firstRep.pixelsHigh, secondRep.pixelsHigh)
        var count = 0
        for y in stride(from: max(0, height - 220), to: height, by: 4) {
            for x in stride(from: max(0, width - 420), to: width, by: 4) {
                let a = firstRep.colorAt(x: x, y: y) ?? .clear
                let b = secondRep.colorAt(x: x, y: y) ?? .clear
                if abs(a.redComponent - b.redComponent) +
                    abs(a.greenComponent - b.greenComponent) +
                    abs(a.blueComponent - b.blueComponent) > 0.08 {
                    count += 1
                }
            }
        }
        return count
    }
}
