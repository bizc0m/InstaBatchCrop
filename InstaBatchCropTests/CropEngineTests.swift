import CoreGraphics
import Testing
@testable import InstaBatchCropCore

@Suite("CropEngine")
struct CropEngineTests {
    let engine = CropEngine()
    let settings = CropSettings.standard

    @Test func singleSubjectIsKeptForSquare() {
        let decision = engine.decide(
            imageSize: CGSize(width: 3000, height: 2000),
            observations: [SubjectObservation(rect: CGRect(x: 1200, y: 700, width: 500, height: 700), confidence: 0.9, kind: .person)],
            target: .square,
            settings: settings
        )
        #expect(decision.cropRect.contains(decision.subjectRect))
        #expect(decision.score > 0.6)
    }

    @Test func faceNearEdgeDoesNotGetCut() {
        let face = CGRect(x: 70, y: 120, width: 240, height: 260)
        let decision = engine.decide(
            imageSize: CGSize(width: 1600, height: 1200),
            observations: [SubjectObservation(rect: face, confidence: 0.96, kind: .face)],
            target: .portrait4x5,
            settings: settings
        )
        #expect(decision.cropRect.contains(face))
    }

    @Test func multiplePeopleStayGroupedWhenPossible() {
        let people = [
            SubjectObservation(rect: CGRect(x: 220, y: 350, width: 350, height: 900), confidence: 0.9, kind: .person),
            SubjectObservation(rect: CGRect(x: 1280, y: 330, width: 380, height: 920), confidence: 0.9, kind: .person)
        ]
        let decision = engine.decide(
            imageSize: CGSize(width: 2000, height: 1500),
            observations: people,
            target: .square,
            settings: CropSettings(mode: .preserveSubject, fallbackMode: .blurredBackground, margin: 0.10, jpegQuality: 0.9, preserveMetadata: false, exportType: .jpeg, debugOverlay: false, qualityThreshold: 0.55)
        )
        #expect(decision.cropRect.intersects(people[0].rect))
        #expect(decision.cropRect.intersects(people[1].rect))
    }

    @Test func veryWideSubjectUsesFallbackForStory() {
        let decision = engine.decide(
            imageSize: CGSize(width: 3000, height: 1600),
            observations: [SubjectObservation(rect: CGRect(x: 200, y: 560, width: 2600, height: 500), confidence: 0.9, kind: .object)],
            target: .story9x16,
            settings: settings
        )
        #expect(decision.usesFallback)
    }

    @Test func landscapeToPortraitPreservesSubject() {
        let subject = CGRect(x: 1350, y: 500, width: 500, height: 800)
        let decision = engine.decide(
            imageSize: CGSize(width: 3200, height: 1800),
            observations: [SubjectObservation(rect: subject, confidence: 0.85, kind: .person)],
            target: .portrait4x5,
            settings: settings
        )
        #expect(decision.cropRect.contains(subject))
    }

    @Test func noSubjectUsesCenterFallbackObservation() {
        let decision = engine.decide(
            imageSize: CGSize(width: 1800, height: 1800),
            observations: [],
            target: .square,
            settings: settings
        )
        #expect(decision.cropRect.midX == 900)
        #expect(decision.cropRect.midY == 900)
    }

    @Test func lowResolutionStillReturnsValidCrop() {
        let decision = engine.decide(
            imageSize: CGSize(width: 640, height: 480),
            observations: [SubjectObservation(rect: CGRect(x: 240, y: 100, width: 180, height: 260), confidence: 0.8, kind: .face)],
            target: .portrait4x5,
            settings: settings
        )
        #expect(decision.cropRect.width <= 640)
        #expect(decision.cropRect.height <= 480)
    }

    @Test func exifOrientationMathUsesPixelSpace() {
        let face = CGRect(x: 250, y: 90, width: 160, height: 190)
        let decision = engine.decide(
            imageSize: CGSize(width: 900, height: 1200),
            observations: [SubjectObservation(rect: face, confidence: 0.9, kind: .face)],
            target: .portrait4x5,
            settings: settings
        )
        #expect(decision.cropRect.contains(face))
    }
}
