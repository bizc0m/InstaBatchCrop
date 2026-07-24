import AppKit
import CoreGraphics
import Foundation

public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case portrait4x5
    case square
    case story9x16

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .portrait4x5: "Portrait 4:5"
        case .square: "Carre 1:1"
        case .story9x16: "Story 9:16"
        }
    }

    public var suffix: String {
        switch self {
        case .portrait4x5: "4x5"
        case .square: "square"
        case .story9x16: "story"
        }
    }

    public var pixelSize: CGSize {
        switch self {
        case .portrait4x5: CGSize(width: 1080, height: 1350)
        case .square: CGSize(width: 1080, height: 1080)
        case .story9x16: CGSize(width: 1080, height: 1920)
        }
    }

    public var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }
}

public enum CropMode: String, CaseIterable, Identifiable, Sendable {
    case strictCenter
    case natural
    case preserveSubject

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .strictCenter: "Centrage strict"
        case .natural: "Cadrage naturel"
        case .preserveSubject: "Preserver tout"
        }
    }
}

public enum FallbackMode: String, CaseIterable, Identifiable, Sendable {
    case blurredBackground
    case solidBackground
    case keepWholeImage
    case maximumCrop

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blurredBackground: "Fond floute"
        case .solidBackground: "Fond uni"
        case .keepWholeImage: "Image entiere"
        case .maximumCrop: "Recadrage max"
        }
    }
}

public enum ExportFileType: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case webp

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .webp: "webp"
        }
    }
}

public enum WatermarkPosition: String, CaseIterable, Identifiable, Sendable {
    case bottomRight
    case bottomLeft
    case topRight
    case topLeft
    case center

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bottomRight: "Bas droite"
        case .bottomLeft: "Bas gauche"
        case .topRight: "Haut droite"
        case .topLeft: "Haut gauche"
        case .center: "Centre"
        }
    }
}

public struct WatermarkSettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var text: String
    public var imageURL: URL?
    public var position: WatermarkPosition
    public var color: WatermarkColor
    public var opacity: CGFloat
    public var size: CGFloat
    public var margin: CGFloat

    public init(
        isEnabled: Bool = false,
        text: String = "InstaBatch Crop",
        imageURL: URL? = nil,
        position: WatermarkPosition = .bottomRight,
        color: WatermarkColor = .white,
        opacity: CGFloat = 0.45,
        size: CGFloat = 42,
        margin: CGFloat = 48
    ) {
        self.isEnabled = isEnabled
        self.text = text
        self.imageURL = imageURL
        self.position = position
        self.color = color
        self.opacity = opacity
        self.size = size
        self.margin = margin
    }

    public static let disabled = WatermarkSettings()
}

public struct WatermarkColor: Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = WatermarkColor(red: 1, green: 1, blue: 1)
}

public enum SubjectKind: String, Sendable {
    case face
    case person
    case animal
    case object
    case saliency
    case imageCenter
    case manualPoint
    case manualZone
}

public struct SubjectObservation: Equatable, Sendable {
    public var rect: CGRect
    public var confidence: CGFloat
    public var kind: SubjectKind

    public init(rect: CGRect, confidence: CGFloat, kind: SubjectKind) {
        self.rect = rect
        self.confidence = confidence
        self.kind = kind
    }

    public var weight: CGFloat {
        switch kind {
        case .manualZone: 5.0
        case .manualPoint: 4.5
        case .face: 3.0
        case .person: 2.2
        case .animal: 2.0
        case .object: 1.5
        case .saliency: 1.1
        case .imageCenter: 0.6
        }
    }
}

public enum FocusAnnotationKind: String, Sendable {
    case point
    case zone
}

public struct FocusAnnotation: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: FocusAnnotationKind
    public var rect: CGRect

    public init(id: UUID = UUID(), kind: FocusAnnotationKind, rect: CGRect) {
        self.id = id
        self.kind = kind
        self.rect = rect
    }

    public func observation(in imageSize: CGSize) -> SubjectObservation {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        let clamped = rect.intersection(imageRect)
        let safeRect = clamped.isNull || clamped.isEmpty ? CGRect(
            x: min(max(0, rect.midX - imageSize.width * 0.04), imageSize.width),
            y: min(max(0, rect.midY - imageSize.height * 0.04), imageSize.height),
            width: max(1, imageSize.width * 0.08),
            height: max(1, imageSize.height * 0.08)
        ).intersection(imageRect) : clamped
        return SubjectObservation(
            rect: safeRect,
            confidence: 1,
            kind: kind == .point ? .manualPoint : .manualZone
        )
    }
}

public struct CropSettings: Sendable {
    public var mode: CropMode
    public var fallbackMode: FallbackMode
    public var margin: CGFloat
    public var jpegQuality: CGFloat
    public var preserveMetadata: Bool
    public var exportType: ExportFileType
    public var debugOverlay: Bool
    public var qualityThreshold: CGFloat
    public var watermark: WatermarkSettings

    public init(
        mode: CropMode,
        fallbackMode: FallbackMode,
        margin: CGFloat,
        jpegQuality: CGFloat,
        preserveMetadata: Bool,
        exportType: ExportFileType,
        debugOverlay: Bool,
        qualityThreshold: CGFloat,
        watermark: WatermarkSettings = .disabled
    ) {
        self.mode = mode
        self.fallbackMode = fallbackMode
        self.margin = margin
        self.jpegQuality = jpegQuality
        self.preserveMetadata = preserveMetadata
        self.exportType = exportType
        self.debugOverlay = debugOverlay
        self.qualityThreshold = qualityThreshold
        self.watermark = watermark
    }

    public static let standard = CropSettings(
        mode: .natural,
        fallbackMode: .blurredBackground,
        margin: 0.14,
        jpegQuality: 0.92,
        preserveMetadata: false,
        exportType: .jpeg,
        debugOverlay: false,
        qualityThreshold: 0.62,
        watermark: .disabled
    )
}

public struct CropDecision: Equatable, Sendable {
    public var cropRect: CGRect
    public var subjectRect: CGRect
    public var score: CGFloat
    public var usesFallback: Bool
    public var reason: String
}

public struct ImportedImage: Identifiable, Hashable {
    public let id = UUID()
    public let url: URL
    public var preview: NSImage?
    public var status: String = "Pret"

    public init(url: URL, preview: NSImage? = nil, status: String = "Pret") {
        self.url = url
        self.preview = preview
        self.status = status
    }
}

public struct BatchResult: Identifiable, Sendable {
    public let id = UUID()
    public var inputURL: URL
    public var outputURL: URL?
    public var format: OutputFormat
    public var status: String
    public var message: String

    public init(inputURL: URL, outputURL: URL?, format: OutputFormat, status: String, message: String) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.format = format
        self.status = status
        self.message = message
    }
}
