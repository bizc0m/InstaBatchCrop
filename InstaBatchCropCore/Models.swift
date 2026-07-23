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
        case .maximumCrop: "Recadrage maximal"
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

public enum SubjectKind: String, Sendable {
    case face
    case person
    case animal
    case object
    case saliency
    case imageCenter
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
        case .face: 3.0
        case .person: 2.2
        case .animal: 2.0
        case .object: 1.5
        case .saliency: 1.1
        case .imageCenter: 0.6
        }
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

    public init(
        mode: CropMode,
        fallbackMode: FallbackMode,
        margin: CGFloat,
        jpegQuality: CGFloat,
        preserveMetadata: Bool,
        exportType: ExportFileType,
        debugOverlay: Bool,
        qualityThreshold: CGFloat
    ) {
        self.mode = mode
        self.fallbackMode = fallbackMode
        self.margin = margin
        self.jpegQuality = jpegQuality
        self.preserveMetadata = preserveMetadata
        self.exportType = exportType
        self.debugOverlay = debugOverlay
        self.qualityThreshold = qualityThreshold
    }

    public static let standard = CropSettings(
        mode: .natural,
        fallbackMode: .blurredBackground,
        margin: 0.14,
        jpegQuality: 0.92,
        preserveMetadata: false,
        exportType: .jpeg,
        debugOverlay: false,
        qualityThreshold: 0.62
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
