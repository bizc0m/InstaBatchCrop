import Foundation

public final class BatchProcessor: Sendable {
    private let analyzer: VisionSubjectAnalyzer
    private let engine: CropEngine
    private let renderer: ImageRenderer

    public init(
        analyzer: VisionSubjectAnalyzer = VisionSubjectAnalyzer(),
        engine: CropEngine = CropEngine(),
        renderer: ImageRenderer = ImageRenderer()
    ) {
        self.analyzer = analyzer
        self.engine = engine
        self.renderer = renderer
    }

    public func process(
        urls: [URL],
        formats: Set<OutputFormat>,
        outputDirectory: URL,
        settings: CropSettings,
        decisionOverrides: [String: CropDecision] = [:],
        progress: @Sendable @escaping (Int, Int) async -> Void
    ) async -> [BatchResult] {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let total = max(1, urls.count * formats.count)
        let counter = Counter()

        return await withTaskGroup(of: [BatchResult].self) { group in
            for inputURL in urls {
                group.addTask {
                    var imageResults: [BatchResult] = []
                    do {
                        let analysis = try self.analyzer.analyze(imageURL: inputURL)
                        for format in formats.sorted(by: { $0.rawValue < $1.rawValue }) {
                            let automaticDecision = self.engine.decide(
                                imageSize: analysis.size,
                                observations: analysis.observations,
                                target: format,
                                settings: settings
                            )
                            let decision = decisionOverrides[Self.overrideKey(inputURL: inputURL, format: format)] ?? automaticDecision
                            let rendered = try self.renderer.render(
                                inputURL: inputURL,
                                target: format,
                                decision: decision,
                                observations: analysis.observations,
                                settings: settings
                            )
                            let outputURL = outputDirectory.appendingPathComponent(
                                Self.outputName(for: inputURL, format: format, settings: settings)
                            )
                            try self.renderer.write(rendered, to: outputURL, settings: settings)
                            imageResults.append(BatchResult(
                                inputURL: inputURL,
                                outputURL: outputURL,
                                format: format,
                                status: "Traite",
                                message: "\(decision.reason), score \(String(format: "%.2f", Double(decision.score)))"
                            ))
                            let value = await counter.increment()
                            await progress(value, total)
                        }
                    } catch {
                        for format in formats {
                            imageResults.append(BatchResult(inputURL: inputURL, outputURL: nil, format: format, status: "Erreur", message: error.localizedDescription))
                            let value = await counter.increment()
                            await progress(value, total)
                        }
                    }
                    return imageResults
                }
            }

            var results: [BatchResult] = []
            for await imageResults in group {
                results += imageResults
            }
            return results.sorted { $0.inputURL.lastPathComponent < $1.inputURL.lastPathComponent }
        }
    }

    public static func makeExportDirectory(near urls: [URL]) -> URL {
        let base = urls.first?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return base.appendingPathComponent("InstaBatchCrop_Export_\(formatter.string(from: Date()))", isDirectory: true)
    }

    public static func overrideKey(inputURL: URL, format: OutputFormat) -> String {
        "\(inputURL.path)|\(format.rawValue)"
    }

    private static func outputName(for inputURL: URL, format: OutputFormat, settings: CropSettings) -> String {
        let stem = inputURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
        return "\(stem)_\(format.suffix).\(settings.exportType.fileExtension)"
    }
}

private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
