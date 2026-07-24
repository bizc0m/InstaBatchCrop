import AppKit
import CoreImage
import InstaBatchCropCore
import SwiftUI
import UniformTypeIdentifiers

enum FocusTool: String, CaseIterable, Identifiable {
    case none
    case point
    case zone

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .none: language == .fr ? "Aucun" : "None"
        case .point: language == .fr ? "Point" : "Point"
        case .zone: language == .fr ? "Zone" : "Area"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case fr = "FR"
    case en = "EN"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var language: AppLanguage = .fr
    @Published var images: [ImportedImage] = []
    @Published var selectedIDs: Set<ImportedImage.ID> = [] {
        didSet {
            guard selectedIDs != oldValue else { return }
            if let newlySelected = selectedIDs.subtracting(oldValue).first {
                primarySelectedID = newlySelected
            } else if let primarySelectedID, !selectedIDs.contains(primarySelectedID) {
                self.primarySelectedID = selectedIDs.first
            } else if primarySelectedID == nil {
                primarySelectedID = selectedIDs.first
            }
            schedulePreviewRefresh()
        }
    }
    @Published var selectedFormats: Set<OutputFormat> = [.portrait4x5, .square] { didSet { schedulePreviewRefresh() } }
    @Published var cropMode: CropMode = .natural { didSet { schedulePreviewRefresh() } }
    @Published var fallbackMode: FallbackMode = .blurredBackground { didSet { schedulePreviewRefresh() } }
    @Published var margin: CGFloat = 0.14 { didSet { schedulePreviewRefresh() } }
    @Published var jpegQuality: CGFloat = 0.92
    @Published var preserveMetadata = false
    @Published var debugOverlay = false { didSet { schedulePreviewRefresh() } }
    @Published var exportType: ExportFileType = .jpeg
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var results: [BatchResult] = []
    @Published var afterPreview: NSImage?
    @Published var previewDecision: CropDecision?
    @Published var previewFormat: OutputFormat = .portrait4x5
    @Published var previewImageSize: CGSize = .zero
    @Published var manualOffsetX: CGFloat = 0 { didSet { manualSliderChanged() } }
    @Published var manualOffsetY: CGFloat = 0 { didSet { manualSliderChanged() } }
    @Published var manualZoom: CGFloat = 1 { didSet { manualSliderChanged() } }
    @Published var handToolEnabled = false
    @Published var isDraggingPreview = false
    @Published var focusTool: FocusTool = .none
    @Published var watermarkEnabled = false { didSet { schedulePreviewRefresh() } }
    @Published var watermarkText = "InstaBatch Crop" { didSet { schedulePreviewRefresh() } }
    @Published var watermarkImageURL: URL? { didSet { schedulePreviewRefresh() } }
    @Published var watermarkColor = Color.white { didSet { schedulePreviewRefresh() } }
    @Published var watermarkPosition: WatermarkPosition = .bottomRight { didSet { schedulePreviewRefresh() } }
    @Published var watermarkOpacity: CGFloat = 0.45 { didSet { schedulePreviewRefresh() } }
    @Published var watermarkSize: CGFloat = 42 { didSet { schedulePreviewRefresh() } }
    @Published var watermarkMargin: CGFloat = 48 { didSet { schedulePreviewRefresh() } }

    private let processor = BatchProcessor()
    private let analyzer = VisionSubjectAnalyzer()
    private let engine = CropEngine()
    private let renderer = ImageRenderer()
    private var manualDecisions: [String: CropDecision] = [:]
    private var focusAnnotations: [String: [FocusAnnotation]] = [:]
    private var primarySelectedID: ImportedImage.ID?
    private var lastPreviewAnalysis: (url: URL, imageSize: CGSize, observations: [SubjectObservation], format: OutputFormat)?
    private var previewRefreshTask: Task<Void, Never>?

    var selectedImage: ImportedImage? {
        if let primarySelectedID,
           let selected = images.first(where: { $0.id == primarySelectedID }) {
            return selected
        }
        return images.first
    }

    var currentFocusAnnotations: [FocusAnnotation] {
        guard let selectedImage else { return [] }
        return focusAnnotations[selectedImage.url.path] ?? []
    }

    func setFormat(_ format: OutputFormat, enabled: Bool) {
        if enabled {
            selectedFormats.insert(format)
        } else {
            selectedFormats.remove(format)
        }
        requestPreviewRefresh()
    }

    func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .webP]
        if panel.runModal() == .OK {
            addURLs(panel.urls)
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let folder = panel.url {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )) ?? []
            addURLs(urls)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in self.addURLs([url]) }
            }
        }
        return true
    }

    func addURLs(_ urls: [URL]) {
        let valid = urls.filter { Self.isSupportedImage($0) }
        let existing = Set(images.map(\.url))
        let newImages = valid.filter { !existing.contains($0) }.map {
            ImportedImage(url: $0, preview: NSImage(contentsOf: $0), status: "Pret")
        }
        images.append(contentsOf: newImages)
        if selectedIDs.isEmpty, let first = images.first?.id {
            selectedIDs = [first]
            primarySelectedID = first
        }
    }

    func removeSelectedImages() {
        guard !selectedIDs.isEmpty else { return }
        let removedPaths = Set(images.filter { selectedIDs.contains($0.id) }.map(\.url.path))
        images.removeAll { selectedIDs.contains($0.id) }
        manualDecisions = manualDecisions.filter { key, _ in
            !removedPaths.contains(where: { key.hasPrefix("\($0)|") })
        }
        selectedIDs = images.first.map { [$0.id] } ?? []
        primarySelectedID = images.first?.id
        afterPreview = nil
        previewDecision = nil
        lastPreviewAnalysis = nil
    }

    func clearQueue() {
        images.removeAll()
        selectedIDs.removeAll()
        primarySelectedID = nil
        manualDecisions.removeAll()
        results.removeAll()
        afterPreview = nil
        previewDecision = nil
        lastPreviewAnalysis = nil
        progress = 0
    }

    func settings() -> CropSettings {
        CropSettings(
            mode: cropMode,
            fallbackMode: fallbackMode,
            margin: margin,
            jpegQuality: jpegQuality,
            preserveMetadata: preserveMetadata,
            exportType: exportType,
            debugOverlay: debugOverlay,
            qualityThreshold: 0.62,
            watermark: WatermarkSettings(
                isEnabled: watermarkEnabled,
                text: watermarkText,
                imageURL: watermarkImageURL,
                position: watermarkPosition,
                color: watermarkCoreColor(),
                opacity: watermarkOpacity,
                size: watermarkSize,
                margin: watermarkMargin
            )
        )
    }

    func generatePreview() async {
        guard let image = selectedImage else { return }
        let format = selectedFormats.sorted { $0.rawValue < $1.rawValue }.first ?? .portrait4x5
        do {
            let analysis = try analyzer.analyze(imageURL: image.url)
            let priorityObservations = focusObservations(for: image.url, imageSize: analysis.size)
            let decisionObservations = priorityObservations.isEmpty ? analysis.observations : priorityObservations
            let automatic = engine.decide(imageSize: analysis.size, observations: decisionObservations, target: format, settings: settings())
            let key = BatchProcessor.overrideKey(inputURL: image.url, format: format)
            let decision = manualDecisions[key] ?? adjust(automatic, imageSize: analysis.size)
            storeManualDecisionIfNeeded(decision, key: key)
            let rendered = try renderer.render(inputURL: image.url, target: format, decision: decision, observations: analysis.observations + priorityObservations, settings: settings())
            afterPreview = NSImage(cgImage: rendered.image, size: format.pixelSize)
            previewDecision = decision
            previewFormat = format
            previewImageSize = analysis.size
            lastPreviewAnalysis = (image.url, analysis.size, analysis.observations, format)
        } catch {
            updateStatus(for: image.id, status: error.localizedDescription)
        }
    }

    func schedulePreviewRefresh(delayMilliseconds: UInt64 = 180) {
        guard selectedImage != nil, !isDraggingPreview else { return }
        previewRefreshTask?.cancel()
        previewRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            await self?.generatePreview()
        }
    }

    func selectWatermarkImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .webP]
        if panel.runModal() == .OK {
            watermarkImageURL = panel.url
            watermarkEnabled = true
            requestPreviewRefresh()
        }
    }

    func clearWatermarkImage() {
        watermarkImageURL = nil
        requestPreviewRefresh()
    }

    func updateWatermarkText(_ text: String) {
        watermarkText = text
        requestPreviewRefresh()
    }

    func updateWatermarkColor(_ color: Color) {
        watermarkColor = color
        requestPreviewRefresh()
    }

    func requestPreviewRefresh() {
        schedulePreviewRefresh(delayMilliseconds: 160)
    }

    private func manualSliderChanged() {
        guard selectedImage != nil else { return }
        invalidateCurrentManualDecision()
        schedulePreviewRefresh()
    }

    func applyManualCrop() {
        guard let image = selectedImage, var decision = previewDecision else { return }
        let format = selectedFormats.sorted { $0.rawValue < $1.rawValue }.first ?? .portrait4x5
        decision.usesFallback = false
        decision.reason = "Correction manuelle appliquee"
        manualDecisions[BatchProcessor.overrideKey(inputURL: image.url, format: format)] = decision
        updateStatus(for: image.id, status: "Correction manuelle")
    }

    func resetManualCorrection() {
        guard let image = selectedImage else { return }
        manualOffsetX = 0
        manualOffsetY = 0
        manualZoom = 1
        removeManualDecisions(for: image.url)
        updateStatus(for: image.id, status: "Correction remise a zero")
        requestPreviewRefresh()
    }

    func applyPreviewDrag(_ translation: CGSize, previewSize: CGSize) {
        guard let image = selectedImage,
              let decision = previewDecision,
              let analysis = lastPreviewAnalysis,
              analysis.url == image.url,
              previewSize.width > 1,
              previewSize.height > 1 else { return }
        let moved = engine.moveCrop(
            decision,
            imageSize: analysis.imageSize,
            outputTranslation: translation,
            outputSize: previewSize
        )
        let key = BatchProcessor.overrideKey(inputURL: image.url, format: analysis.format)
        manualDecisions[key] = moved
        previewDecision = moved
        updateStatus(for: image.id, status: "Correction main")
    }

    func finishPreviewDrag() {
        isDraggingPreview = false
        Task { await renderCurrentManualPreview() }
    }

    func selectPreviousImage() {
        selectRelativeImage(offset: -1)
    }

    func selectNextImage() {
        selectRelativeImage(offset: 1)
    }

    func addFocusPoint(_ point: CGPoint, imageSize: CGSize) {
        guard let image = selectedImage else { return }
        let diameter = max(18, min(imageSize.width, imageSize.height) * 0.08)
        let rect = CGRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        addFocusAnnotation(FocusAnnotation(kind: .point, rect: rect), for: image.url, imageSize: imageSize)
    }

    func addFocusZone(_ rect: CGRect, imageSize: CGSize) {
        guard let image = selectedImage else { return }
        let normalized = rect.standardized
        guard normalized.width > 6, normalized.height > 6 else { return }
        addFocusAnnotation(FocusAnnotation(kind: .zone, rect: normalized), for: image.url, imageSize: imageSize)
    }

    func clearFocusAnnotationsForSelection() {
        guard let image = selectedImage else { return }
        focusAnnotations[image.url.path] = []
        removeManualDecisions(for: image.url)
        updateStatus(for: image.id, status: "Interets effaces")
        requestPreviewRefresh()
    }

    private func renderCurrentManualPreview() async {
        guard let image = selectedImage,
              let decision = previewDecision,
              let analysis = lastPreviewAnalysis,
              analysis.url == image.url else { return }
        let priorityObservations = focusObservations(for: image.url, imageSize: analysis.imageSize)
        do {
            let rendered = try renderer.render(
                inputURL: image.url,
                target: analysis.format,
                decision: decision,
                observations: analysis.observations + priorityObservations,
                settings: settings()
            )
            afterPreview = NSImage(cgImage: rendered.image, size: analysis.format.pixelSize)
        } catch {
            updateStatus(for: image.id, status: error.localizedDescription)
        }
    }

    func processAll() async {
        guard !images.isEmpty else { return }
        isProcessing = true
        progress = 0
        results = []
        let urls = images.map(\.url)
        let outputDirectory = BatchProcessor.makeExportDirectory(near: urls)
        let activeSettings = settings()
        let activeFocus = await buildFocusObservationMap(for: images)
        results = await processor.process(urls: urls, formats: selectedFormats, outputDirectory: outputDirectory, settings: activeSettings, decisionOverrides: manualDecisions, focusObservations: activeFocus) { done, total in
            await MainActor.run {
                self.progress = Double(done) / Double(total)
            }
        }
        for result in results {
            if let index = images.firstIndex(where: { $0.url == result.inputURL }) {
                images[index].status = result.status
            }
        }
        isProcessing = false
        NSWorkspace.shared.activateFileViewerSelecting(results.compactMap(\.outputURL))
    }

    private func updateStatus(for id: ImportedImage.ID, status: String) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        images[index].status = status
    }

    private func selectRelativeImage(offset: Int) {
        guard !images.isEmpty else { return }
        let currentIndex = selectedImage.flatMap { selected in images.firstIndex(where: { $0.id == selected.id }) } ?? 0
        let nextIndex = min(max(0, currentIndex + offset), images.count - 1)
        let id = images[nextIndex].id
        primarySelectedID = id
        selectedIDs = [id]
        requestPreviewRefresh()
    }

    private func addFocusAnnotation(_ annotation: FocusAnnotation, for url: URL, imageSize: CGSize) {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        let safeRect = annotation.rect.intersection(imageRect)
        guard !safeRect.isNull, !safeRect.isEmpty else { return }
        focusAnnotations[url.path, default: []].append(FocusAnnotation(kind: annotation.kind, rect: safeRect))
        removeManualDecisions(for: url)
        if let image = selectedImage {
            updateStatus(for: image.id, status: "\(focusAnnotations[url.path]?.count ?? 0) interet(s)")
        }
        requestPreviewRefresh()
    }

    private func removeManualDecisions(for url: URL) {
        manualDecisions = manualDecisions.filter { key, _ in
            !key.hasPrefix("\(url.path)|")
        }
    }

    private func invalidateCurrentManualDecision() {
        guard let image = selectedImage else { return }
        let format = selectedFormats.sorted { $0.rawValue < $1.rawValue }.first ?? .portrait4x5
        manualDecisions.removeValue(forKey: BatchProcessor.overrideKey(inputURL: image.url, format: format))
    }

    private func storeManualDecisionIfNeeded(_ decision: CropDecision, key: String) {
        guard manualOffsetX != 0 || manualOffsetY != 0 || manualZoom != 1 else { return }
        manualDecisions[key] = decision
    }

    private func focusObservations(for url: URL, imageSize: CGSize) -> [SubjectObservation] {
        (focusAnnotations[url.path] ?? []).map { $0.observation(in: imageSize) }
    }

    private func buildFocusObservationMap(for images: [ImportedImage]) async -> [String: [SubjectObservation]] {
        var output: [String: [SubjectObservation]] = [:]
        for image in images where !(focusAnnotations[image.url.path] ?? []).isEmpty {
            if let analysis = try? analyzer.analyze(imageURL: image.url) {
                output[image.url.path] = focusObservations(for: image.url, imageSize: analysis.size)
            }
        }
        return output
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(lower, value), upper)
    }

    private func watermarkCoreColor() -> WatermarkColor {
        let nsColor = NSColor(watermarkColor).usingColorSpace(.sRGB) ?? .white
        return WatermarkColor(red: nsColor.redComponent, green: nsColor.greenComponent, blue: nsColor.blueComponent)
    }

    private func adjust(_ decision: CropDecision, imageSize: CGSize) -> CropDecision {
        guard manualOffsetX != 0 || manualOffsetY != 0 || manualZoom != 1 else { return decision }
        var adjusted = decision
        var rect = decision.cropRect
        let nextWidth = min(imageSize.width, rect.width / manualZoom)
        let nextHeight = min(imageSize.height, rect.height / manualZoom)
        rect.origin.x = rect.midX - nextWidth / 2 + manualOffsetX * rect.width * 0.75
        rect.origin.y = rect.midY - nextHeight / 2 + manualOffsetY * rect.height * 0.75
        rect.size = CGSize(width: nextWidth, height: nextHeight)
        rect.origin.x = min(max(0, rect.origin.x), imageSize.width - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), imageSize.height - rect.height)
        adjusted.cropRect = rect
        adjusted.usesFallback = false
        adjusted.reason = "Correction manuelle"
        return adjusted
    }

    private static func isSupportedImage(_ url: URL) -> Bool {
        ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp"].contains(url.pathExtension.lowercased())
    }
}
