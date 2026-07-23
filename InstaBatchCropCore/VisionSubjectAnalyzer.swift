import AppKit
import CoreImage
import CoreGraphics
import Foundation
import Vision

public struct VisionSubjectAnalyzer: Sendable {
    public init() {}

    public func analyze(imageURL: URL) throws -> (size: CGSize, observations: [SubjectObservation]) {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else {
            throw ProcessingError.cannotReadImage(imageURL)
        }

        let orientation = CGImagePropertyOrientation.fromImageSource(source)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()

        var requests: [VNRequest] = [faceRequest, humanRequest, attentionRequest, objectnessRequest]
        if #available(macOS 14.0, *) {
            requests.append(VNRecognizeAnimalsRequest())
        }
        try handler.perform(requests)

        var observations: [SubjectObservation] = []
        observations += (faceRequest.results ?? []).map {
            SubjectObservation(rect: convert($0.boundingBox, imageSize: imageSize), confidence: CGFloat($0.confidence), kind: .face)
        }
        observations += (humanRequest.results ?? []).map {
            SubjectObservation(rect: convert($0.boundingBox, imageSize: imageSize), confidence: CGFloat($0.confidence), kind: .person)
        }
        observations += salientObjects(from: attentionRequest.results, imageSize: imageSize, kind: .saliency)
        observations += salientObjects(from: objectnessRequest.results, imageSize: imageSize, kind: .object)

        if #available(macOS 14.0, *) {
            if let animalRequest = requests.compactMap({ $0 as? VNRecognizeAnimalsRequest }).first {
                observations += (animalRequest.results ?? []).map {
                    SubjectObservation(rect: convert($0.boundingBox, imageSize: imageSize), confidence: CGFloat($0.confidence), kind: .animal)
                }
            }
        }

        if observations.isEmpty {
            observations.append(SubjectObservation(
                rect: CGRect(
                    x: imageSize.width * 0.25,
                    y: imageSize.height * 0.25,
                    width: imageSize.width * 0.5,
                    height: imageSize.height * 0.5
                ),
                confidence: 0.35,
                kind: .imageCenter
            ))
        }

        return (imageSize, observations)
    }

    private func salientObjects(from results: [VNSaliencyImageObservation]?, imageSize: CGSize, kind: SubjectKind) -> [SubjectObservation] {
        guard let observation = results?.first else { return [] }
        return observation.salientObjects?.map {
            SubjectObservation(rect: convert($0.boundingBox, imageSize: imageSize), confidence: CGFloat($0.confidence), kind: kind)
        } ?? []
    }

    private func convert(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.minX * imageSize.width,
            y: (1 - normalizedRect.maxY) * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
    }
}

extension CGImagePropertyOrientation {
    static func fromImageSource(_ source: CGImageSource) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32 else {
            return .up
        }
        return CGImagePropertyOrientation(rawValue: raw) ?? .up
    }
}

public enum ProcessingError: LocalizedError, Sendable {
    case cannotReadImage(URL)
    case cannotRender(URL)
    case cannotWrite(URL)

    public var errorDescription: String? {
        switch self {
        case .cannotReadImage(let url): "Lecture impossible: \(url.lastPathComponent)"
        case .cannotRender(let url): "Rendu impossible: \(url.lastPathComponent)"
        case .cannotWrite(let url): "Ecriture impossible: \(url.lastPathComponent)"
        }
    }
}
