import CoreGraphics
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
}
