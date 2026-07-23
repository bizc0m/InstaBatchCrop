import CoreGraphics
import Foundation

public struct CropEngine: Sendable {
    public init() {}

    public func decide(
        imageSize: CGSize,
        observations: [SubjectObservation],
        target: OutputFormat,
        settings: CropSettings
    ) -> CropDecision {
        guard imageSize.width > 1, imageSize.height > 1 else {
            return CropDecision(
                cropRect: CGRect(origin: .zero, size: imageSize),
                subjectRect: CGRect(origin: .zero, size: imageSize),
                score: 0,
                usesFallback: true,
                reason: "Image invalide"
            )
        }

        let imageRect = CGRect(origin: .zero, size: imageSize)
        let safeObservations = observations.filter { !$0.rect.isEmpty && imageRect.intersects($0.rect) }
        let subjectRect = mergedSubjectRect(
            observations: safeObservations,
            fallback: imageRect.insetBy(dx: imageSize.width * 0.25, dy: imageSize.height * 0.25),
            imageRect: imageRect
        )
        let marginRect = addMargin(to: subjectRect, imageSize: imageSize, margin: settings.margin)
        let baseRect = smallestAspectRect(containing: marginRect, aspectRatio: target.aspectRatio)
        let candidates = makeCandidates(
            baseRect: baseRect,
            imageRect: imageRect,
            targetAspect: target.aspectRatio,
            subjectRect: subjectRect,
            mode: settings.mode
        )

        var bestRect = clamp(baseRect, in: imageRect)
        var bestScore: CGFloat = -1
        for candidate in candidates {
            let score = score(
                cropRect: candidate,
                imageRect: imageRect,
                subjectRect: subjectRect,
                observations: safeObservations,
                mode: settings.mode
            )
            if score > bestScore {
                bestScore = score
                bestRect = candidate
            }
        }

        let containsSubject = bestRect.contains(marginRect)
        let fallback = !containsSubject || bestScore < settings.qualityThreshold
        let allowMaxCrop = settings.fallbackMode == .maximumCrop
        return CropDecision(
            cropRect: bestRect.integral,
            subjectRect: subjectRect.integral,
            score: bestScore,
            usesFallback: fallback && !allowMaxCrop,
            reason: fallback && !allowMaxCrop ? "Ratio cible trop contraint pour preserver le sujet" : "Cadrage direct"
        )
    }

    private func mergedSubjectRect(
        observations: [SubjectObservation],
        fallback: CGRect,
        imageRect: CGRect
    ) -> CGRect {
        guard !observations.isEmpty else { return fallback }
        let important = observations.filter { $0.confidence * $0.weight >= 0.15 }
        let selected = important.isEmpty ? observations : important
        return selected.reduce(CGRect.null) { partial, observation in
            partial.union(observation.rect.intersection(imageRect))
        }
    }

    private func addMargin(to rect: CGRect, imageSize: CGSize, margin: CGFloat) -> CGRect {
        let dx = max(imageSize.width * 0.02, rect.width * margin)
        let dy = max(imageSize.height * 0.02, rect.height * margin)
        return rect.insetBy(dx: -dx, dy: -dy)
    }

    private func smallestAspectRect(containing rect: CGRect, aspectRatio: CGFloat) -> CGRect {
        var width = rect.width
        var height = rect.height
        if width / height < aspectRatio {
            width = height * aspectRatio
        } else {
            height = width / aspectRatio
        }
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func makeCandidates(
        baseRect: CGRect,
        imageRect: CGRect,
        targetAspect: CGFloat,
        subjectRect: CGRect,
        mode: CropMode
    ) -> [CGRect] {
        let maxWidth = min(imageRect.width, imageRect.height * targetAspect)
        let maxHeight = maxWidth / targetAspect
        let scaleSteps: [CGFloat] = switch mode {
        case .strictCenter: [1.0, 1.08, 1.18]
        case .natural: [1.0, 1.08, 1.18, 1.32]
        case .preserveSubject: [1.08, 1.2, 1.36, 1.55, 1.8]
        }

        let offsets: [CGPoint] = [
            .zero,
            CGPoint(x: -0.12, y: 0), CGPoint(x: 0.12, y: 0),
            CGPoint(x: 0, y: -0.10), CGPoint(x: 0, y: 0.10),
            CGPoint(x: -0.08, y: -0.08), CGPoint(x: 0.08, y: -0.08),
            CGPoint(x: -0.08, y: 0.08), CGPoint(x: 0.08, y: 0.08)
        ]

        var candidates: [CGRect] = []
        for scale in scaleSteps {
            let width = min(maxWidth, baseRect.width * scale)
            let height = min(maxHeight, width / targetAspect)
            for offset in offsets {
                var rect = CGRect(
                    x: subjectRect.midX - width / 2 + offset.x * width,
                    y: subjectRect.midY - height / 2 + offset.y * height,
                    width: width,
                    height: height
                )
                if mode == .strictCenter {
                    rect.origin.x = imageRect.midX - width / 2
                    rect.origin.y = imageRect.midY - height / 2
                }
                candidates.append(clamp(rect, in: imageRect).integral)
            }
        }
        var unique: [CGRect] = []
        for candidate in candidates where !unique.contains(where: { $0.equalTo(candidate) }) {
            unique.append(candidate)
        }
        return unique
    }

    private func clamp(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var result = rect
        if result.width > bounds.width {
            result.size.width = bounds.width
            result.size.height = result.width / (rect.width / rect.height)
        }
        if result.height > bounds.height {
            result.size.height = bounds.height
            result.size.width = result.height * (rect.width / rect.height)
        }
        result.origin.x = min(max(bounds.minX, result.origin.x), bounds.maxX - result.width)
        result.origin.y = min(max(bounds.minY, result.origin.y), bounds.maxY - result.height)
        return result
    }

    private func score(
        cropRect: CGRect,
        imageRect: CGRect,
        subjectRect: CGRect,
        observations: [SubjectObservation],
        mode: CropMode
    ) -> CGFloat {
        let subjectCoverage = coverage(of: subjectRect, in: cropRect)
        let faceCoverage = observations
            .filter { $0.kind == .face }
            .map { coverage(of: $0.rect, in: cropRect) }
            .min() ?? 1.0
        let centerDistance = hypot(
            (subjectRect.midX - cropRect.midX) / cropRect.width,
            (subjectRect.midY - cropRect.midY) / cropRect.height
        )
        let centerScore = max(0, 1 - centerDistance * 2.0)
        let topSpace = max(0, (subjectRect.minY - cropRect.minY) / cropRect.height)
        let topScore = min(1, topSpace / 0.12)
        let resolutionScore = min(1, min(cropRect.width / 1080, cropRect.height / 1080))
        let cropAreaPenalty = min(1, cropRect.area / imageRect.area)

        let preserveBoost: CGFloat = mode == .preserveSubject ? 0.12 : 0
        return min(
            1,
            subjectCoverage * 0.34 +
            faceCoverage * 0.24 +
            centerScore * 0.18 +
            topScore * 0.10 +
            resolutionScore * 0.08 +
            cropAreaPenalty * 0.06 +
            preserveBoost
        )
    }

    private func coverage(of rect: CGRect, in container: CGRect) -> CGFloat {
        guard !rect.isEmpty else { return 0 }
        return rect.intersection(container).area / rect.area
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
