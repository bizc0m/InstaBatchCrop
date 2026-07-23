import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import InstaBatchCropCore

@Suite("Watermark")
struct WatermarkTests {
    @Test func defaultWatermarkIsDisabled() {
        let settings = WatermarkSettings.disabled
        #expect(settings.isEnabled == false)
        #expect(settings.position == .bottomRight)
    }

    @Test func placementKeepsBottomRightInsideOutput() {
        let renderer = WatermarkRenderer()
        let settings = WatermarkSettings(isEnabled: true, text: "TEST", position: .bottomRight, opacity: 0.5, size: 40, margin: 32)
        let rect = renderer.placementRect(textSize: CGSize(width: 180, height: 50), outputSize: CGSize(width: 1080, height: 1350), settings: settings)
        #expect(rect.minX >= 0)
        #expect(rect.minY >= 0)
        #expect(rect.maxX <= 1080)
        #expect(rect.maxY <= 1350)
    }

    @Test func centerPlacementIsCentered() {
        let renderer = WatermarkRenderer()
        let settings = WatermarkSettings(isEnabled: true, text: "TEST", position: .center, opacity: 0.5, size: 40, margin: 32)
        let rect = renderer.placementRect(textSize: CGSize(width: 200, height: 80), outputSize: CGSize(width: 1080, height: 1080), settings: settings)
        #expect(rect.midX == 540)
        #expect(rect.midY == 540)
    }

    @Test func enabledWatermarkChangesPixels() throws {
        let base = try Self.makeSolidImage(width: 420, height: 240)
        let renderer = WatermarkRenderer()
        let rendered = renderer.render(
            on: base,
            settings: WatermarkSettings(
                isEnabled: true,
                text: "VISIBLE",
                position: .center,
                color: WatermarkColor(red: 1, green: 0, blue: 0),
                opacity: 1,
                size: 54,
                margin: 12
            )
        )
        #expect(Self.pixelDifferenceCount(base, rendered) > 100)
    }

    @Test func transparentLogoWatermarkChangesPixels() throws {
        let base = try Self.makeSolidImage(width: 420, height: 240)
        let logoURL = try Self.makeTransparentLogo()
        let renderer = WatermarkRenderer()
        let rendered = renderer.render(
            on: base,
            settings: WatermarkSettings(isEnabled: true, text: "", imageURL: logoURL, position: .center, opacity: 0.9, size: 52, margin: 12)
        )
        #expect(Self.pixelDifferenceCount(base, rendered) > 100)
    }

    private static func makeSolidImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ProcessingError.cannotRender(URL(fileURLWithPath: "solid"))
        }
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw ProcessingError.cannotRender(URL(fileURLWithPath: "solid"))
        }
        return image
    }

    private static func pixelDifferenceCount(_ first: CGImage, _ second: CGImage) -> Int {
        let width = min(first.width, second.width)
        let height = min(first.height, second.height)
        var firstData = [UInt8](repeating: 0, count: width * height * 4)
        var secondData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        firstData.withUnsafeMutableBytes { bytes in
            CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(first, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        secondData.withUnsafeMutableBytes { bytes in
            CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(second, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return zip(firstData, secondData).filter { abs(Int($0) - Int($1)) > 8 }.count
    }

    private static func makeTransparentLogo() throws -> URL {
        let width = 160
        let height = 90
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("watermark-logo-\(UUID().uuidString).png")
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ProcessingError.cannotRender(url)
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0.8, blue: 1, alpha: 0.75))
        context.fillEllipse(in: CGRect(x: 20, y: 15, width: 120, height: 60))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ProcessingError.cannotWrite(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.cannotWrite(url)
        }
        return url
    }
}
