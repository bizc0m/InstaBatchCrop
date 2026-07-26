import AppKit
import InstaBatchCropCore
import SwiftUI
import UniformTypeIdentifiers

private extension AppLanguage {
    func text(_ key: String) -> String {
        let fr = [
            "chooseFiles": "Choisir fichiers",
            "chooseFolder": "Choisir dossier",
            "images": "Images",
            "removeSelected": "Retirer les images selectionnees",
            "clearQueue": "Vider",
            "clearQueueHelp": "Nettoyer toute la file",
            "processAll": "Traiter toutes les photos",
            "language": "Langue",
            "formats": "Formats",
            "mode": "Mode",
            "fallback": "Secours",
            "margin": "Marge",
            "export": "Export",
            "metadata": "Metadonnees",
            "compression": "Compression",
            "debugBoxes": "Debug boxes",
            "watermark": "Watermark",
            "active": "Actif",
            "text": "Texte",
            "logo": "Logo",
            "logoHelp": "Choisir une image watermark, PNG transparent recommande",
            "clearLogo": "Retirer le logo watermark",
            "activeLogo": "Logo actif",
            "position": "Position",
            "opacity": "Opacite",
            "watermarkSize": "Taille watermark",
            "exportPreview": "Apercu export",
            "refresh": "Actualiser",
            "moveCrop": "Deplacer le cadrage dans l'apercu apres",
            "resetManual": "Remettre deplacement et zoom a zero",
            "previousImage": "Image precedente",
            "nextImage": "Image suivante",
            "focusHelp": "Marquer les points ou zones prioritaires sur l'image avant",
            "clearFocus": "Effacer les interets de cette image",
            "interestCount": "interet(s)",
            "before": "Avant",
            "after": "Apres",
            "horizontal": "Deplacement horizontal",
            "vertical": "Deplacement vertical",
            "zoom": "Zoom",
            "report": "Rapport",
            "dropPhotos": "Glisser-deposer des photos"
        ]
        let en = [
            "chooseFiles": "Choose files",
            "chooseFolder": "Choose folder",
            "images": "Images",
            "removeSelected": "Remove selected images",
            "clearQueue": "Clear",
            "clearQueueHelp": "Clear the whole queue",
            "processAll": "Process all photos",
            "language": "Language",
            "formats": "Formats",
            "mode": "Mode",
            "fallback": "Fallback",
            "margin": "Margin",
            "export": "Export",
            "metadata": "Metadata",
            "compression": "Compression",
            "debugBoxes": "Debug boxes",
            "watermark": "Watermark",
            "active": "Active",
            "text": "Text",
            "logo": "Logo",
            "logoHelp": "Choose a watermark image, transparent PNG recommended",
            "clearLogo": "Remove watermark logo",
            "activeLogo": "Active logo",
            "position": "Position",
            "opacity": "Opacity",
            "watermarkSize": "Watermark size",
            "exportPreview": "Export preview",
            "refresh": "Refresh",
            "moveCrop": "Move crop in the after preview",
            "resetManual": "Reset move and zoom",
            "previousImage": "Previous image",
            "nextImage": "Next image",
            "focusHelp": "Mark priority points or areas on the before image",
            "clearFocus": "Clear marks for this image",
            "interestCount": "mark(s)",
            "before": "Before",
            "after": "After",
            "horizontal": "Horizontal move",
            "vertical": "Vertical move",
            "zoom": "Zoom",
            "report": "Report",
            "dropPhotos": "Drag and drop photos"
        ]
        return (self == .fr ? fr : en)[key] ?? key
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
            previewWorkspace
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            inspector
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 430)
        }
        .frame(minWidth: 1180, minHeight: 760)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.selectFiles()
                } label: {
                    Label(viewModel.language.text("chooseFiles"), systemImage: "photo.badge.plus")
                }
                Button {
                    viewModel.selectFolder()
                } label: {
                    Label(viewModel.language.text("chooseFolder"), systemImage: "folder.badge.plus")
                }
                Button {
                    Task { await viewModel.generatePreview() }
                } label: {
                    Label(viewModel.language.text("refresh"), systemImage: "rectangle.on.rectangle")
                }
                .disabled(viewModel.selectedImage == nil)
                Button {
                    Task { await viewModel.processAll() }
                } label: {
                    Label(viewModel.language.text("processAll"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.images.isEmpty || viewModel.selectedFormats.isEmpty || viewModel.isProcessing)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("InstaBatch Crop")
                            .font(.title3.weight(.semibold))
                        Text("V2.3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $viewModel.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 96)
                }

                DropZone(title: viewModel.language.text("dropPhotos"))
                    .frame(height: 128)

                HStack(spacing: 8) {
                    MetricTile(title: viewModel.language.text("images"), value: "\(viewModel.images.count)", symbol: "photo.stack")
                    MetricTile(title: viewModel.language.text("formats"), value: "\(viewModel.selectedFormats.count)", symbol: "rectangle.3.group")
                }
            }
            .padding(16)

            Divider()

            HStack {
                Text(viewModel.language.text("images"))
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.removeSelectedImages()
                } label: {
                    Image(systemName: "trash")
                }
                .help(viewModel.language.text("removeSelected"))
                .disabled(viewModel.selectedIDs.isEmpty)
                Button {
                    viewModel.clearQueue()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help(viewModel.language.text("clearQueueHelp"))
                .disabled(viewModel.images.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            List(selection: $viewModel.selectedIDs) {
                ForEach(viewModel.images) { image in
                    HStack(spacing: 10) {
                        if let preview = image.preview {
                            Image(nsImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        } else {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(.quaternary)
                                .frame(width: 52, height: 52)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(image.url.lastPathComponent)
                                .lineLimit(1)
                                .font(.body.weight(.medium))
                            Text(image.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(image.id)
                }
            }
            .overlay {
                if viewModel.images.isEmpty {
                    ContentUnavailableView(
                        viewModel.language.text("dropPhotos"),
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: viewModel.progress)
                Button {
                    Task { await viewModel.processAll() }
                } label: {
                    Label(viewModel.language.text("processAll"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.images.isEmpty || viewModel.selectedFormats.isEmpty || viewModel.isProcessing)
            }
            .padding(16)
        }
        .background(.regularMaterial)
    }

    private var previewWorkspace: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.language.text("exportPreview"))
                            .font(.title2.weight(.semibold))
                        if let selected = viewModel.selectedImage {
                            Text(selected.url.lastPathComponent)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(viewModel.language.text("dropPhotos"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.selectPreviousImage()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help(viewModel.language.text("previousImage"))
                    .disabled(viewModel.images.isEmpty)
                    Button {
                        viewModel.selectNextImage()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help(viewModel.language.text("nextImage"))
                    .disabled(viewModel.images.isEmpty)
                    Button {
                        viewModel.resetManualCorrection()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help(viewModel.language.text("resetManual"))
                    .disabled(viewModel.previewDecision == nil)
                }

                HStack(spacing: 16) {
                    FocusMarkingPreviewBox(
                        title: viewModel.language.text("before"),
                        image: viewModel.selectedImage?.preview,
                        annotations: viewModel.currentFocusAnnotations,
                        tool: viewModel.focusTool
                    ) { point, imageSize in
                        viewModel.addFocusPoint(point, imageSize: imageSize)
                    } onZone: { rect, imageSize in
                        viewModel.addFocusZone(rect, imageSize: imageSize)
                    }
                    DraggablePreviewBox(
                        title: viewModel.language.text("after"),
                        sourceImage: viewModel.selectedImage?.preview,
                        renderedImage: viewModel.afterPreview,
                        decision: viewModel.previewDecision,
                        imageSize: viewModel.previewImageSize,
                        aspectRatio: viewModel.previewFormat.aspectRatio,
                        showRenderedPreview: viewModel.watermarkEnabled || viewModel.debugOverlay
                    ) { translation, size in
                        viewModel.isDraggingPreview = true
                        viewModel.applyPreviewDrag(translation, previewSize: size)
                    } onDragEnded: {
                        viewModel.finishPreviewDrag()
                    }
                }
                .frame(minHeight: 360)

                HStack(alignment: .center, spacing: 12) {
                    Picker("", selection: $viewModel.focusTool) {
                        ForEach(FocusTool.allCases) { tool in
                            Text(tool.displayName(language: viewModel.language)).tag(tool)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                    .help(viewModel.language.text("focusHelp"))
                    Button {
                        viewModel.clearFocusAnnotationsForSelection()
                    } label: {
                        Label(viewModel.language.text("clearFocus"), systemImage: "eraser")
                    }
                    .disabled(viewModel.currentFocusAnnotations.isEmpty)
                    if !viewModel.currentFocusAnnotations.isEmpty {
                        Text("\(viewModel.currentFocusAnnotations.count) \(viewModel.language.text("interestCount"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                manualAdjustmentBar

                if let decision = viewModel.previewDecision {
                    Text("Score \(String(format: "%.2f", Double(decision.score))) - \(decision.reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(18)

            Divider()

            report
                .frame(minHeight: 170, maxHeight: 230)
                .padding(18)
        }
    }

    private var manualAdjustmentBar: some View {
        HStack(spacing: 14) {
            KeyboardArrowIcon(axis: .horizontal)
                .help(viewModel.language.text("horizontal"))
            Slider(value: $viewModel.manualOffsetX, in: -2...2)
                .frame(minWidth: 120)
            KeyboardArrowIcon(axis: .vertical)
                .help(viewModel.language.text("vertical"))
            Slider(value: $viewModel.manualOffsetY, in: -2...2)
                .frame(minWidth: 120)
            Image(systemName: "magnifyingglass")
                .help(viewModel.language.text("zoom"))
            Slider(value: $viewModel.manualZoom, in: 0.35...3.0)
                .frame(minWidth: 120)
        }
        .padding(12)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsSection(title: viewModel.language.text("formats"), symbol: "rectangle.3.group") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(OutputFormat.allCases) { format in
                            Toggle(outputFormatName(format), isOn: Binding(
                                get: { viewModel.selectedFormats.contains(format) },
                                set: { enabled in viewModel.setFormat(format, enabled: enabled) }
                            ))
                        }
                    }
                }

                SettingsSection(title: viewModel.language.text("mode"), symbol: "crop") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $viewModel.cropMode) {
                            ForEach(CropMode.allCases) { Text(cropModeName($0)).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Picker("", selection: $viewModel.fallbackMode) {
                            ForEach(FallbackMode.allCases) { Text(fallbackModeName($0)).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading) {
                            HStack {
                                Text(viewModel.language.text("margin"))
                                Spacer()
                                Text("\(Int(viewModel.margin * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $viewModel.margin, in: 0.02...0.35)
                        }
                    }
                }

                SettingsSection(title: viewModel.language.text("export"), symbol: "square.and.arrow.down") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $viewModel.exportType) {
                            ForEach(ExportFileType.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading) {
                            Text(viewModel.language.text("compression"))
                            Slider(value: $viewModel.jpegQuality, in: 0.5...1.0)
                        }

                        Toggle(viewModel.language.text("metadata"), isOn: $viewModel.preserveMetadata)
                        Toggle(viewModel.language.text("debugBoxes"), isOn: $viewModel.debugOverlay)
                    }
                }

                SettingsSection(title: viewModel.language.text("watermark"), symbol: "signature") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(viewModel.language.text("active"), isOn: $viewModel.watermarkEnabled)
                        TextField(viewModel.language.text("text"), text: Binding(
                            get: { viewModel.watermarkText },
                            set: { viewModel.updateWatermarkText($0) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        HStack {
                            ColorPicker("", selection: Binding(
                                get: { viewModel.watermarkColor },
                                set: { viewModel.updateWatermarkColor($0) }
                            ))
                            .labelsHidden()
                            Button {
                                viewModel.selectWatermarkImage()
                            } label: {
                                Label(viewModel.language.text("logo"), systemImage: "photo")
                            }
                            .help(viewModel.language.text("logoHelp"))
                            Button {
                                viewModel.clearWatermarkImage()
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .help(viewModel.language.text("clearLogo"))
                            .disabled(viewModel.watermarkImageURL == nil)
                        }

                        if let logoName = viewModel.watermarkImageURL?.lastPathComponent {
                            Text(logoName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Picker(viewModel.language.text("position"), selection: $viewModel.watermarkPosition) {
                            ForEach(WatermarkPosition.allCases) { Text(watermarkPositionName($0)).tag($0) }
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading) {
                            Text(viewModel.language.text("opacity"))
                            Slider(value: $viewModel.watermarkOpacity, in: 0.05...1.0)
                        }
                        VStack(alignment: .leading) {
                            Text(viewModel.language.text("watermarkSize"))
                            Slider(value: $viewModel.watermarkSize, in: 12...120)
                        }
                        VStack(alignment: .leading) {
                            Text(viewModel.language.text("margin"))
                            Slider(value: $viewModel.watermarkMargin, in: 0...160)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(.regularMaterial)
        .onChange(of: viewModel.cropMode) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.fallbackMode) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.margin) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.jpegQuality) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.debugOverlay) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.exportType) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.watermarkEnabled) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.watermarkPosition) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.watermarkOpacity) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.watermarkSize) { _, _ in viewModel.requestPreviewRefresh() }
        .onChange(of: viewModel.watermarkMargin) { _, _ in viewModel.requestPreviewRefresh() }
    }

    private var report: some View {
        VStack(alignment: .leading) {
            Text(viewModel.language.text("report"))
                .font(.headline)
            List(viewModel.results) { result in
                HStack {
                    Text(result.status)
                        .frame(width: 72, alignment: .leading)
                    Text(result.inputURL.lastPathComponent)
                        .lineLimit(1)
                    Text(outputFormatName(result.format))
                    Text(result.message)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func outputFormatName(_ format: OutputFormat) -> String {
        switch format {
        case .portrait4x5: "Portrait 4:5"
        case .square: viewModel.language == .fr ? "Carre 1:1" : "Square 1:1"
        case .story9x16: "Story 9:16"
        }
    }

    private func cropModeName(_ mode: CropMode) -> String {
        switch mode {
        case .strictCenter: viewModel.language == .fr ? "Centrage strict" : "Strict center"
        case .natural: viewModel.language == .fr ? "Cadrage naturel" : "Natural crop"
        case .preserveSubject: viewModel.language == .fr ? "Preserver tout" : "Preserve all"
        }
    }

    private func fallbackModeName(_ mode: FallbackMode) -> String {
        switch mode {
        case .blurredBackground: viewModel.language == .fr ? "Fond floute" : "Blurred bg"
        case .solidBackground: viewModel.language == .fr ? "Fond uni" : "Solid bg"
        case .keepWholeImage: viewModel.language == .fr ? "Image entiere" : "Whole image"
        case .maximumCrop: viewModel.language == .fr ? "Recadrage max" : "Max crop"
        }
    }

    private func watermarkPositionName(_ position: WatermarkPosition) -> String {
        switch position {
        case .bottomRight: viewModel.language == .fr ? "Bas droite" : "Bottom right"
        case .bottomLeft: viewModel.language == .fr ? "Bas gauche" : "Bottom left"
        case .topRight: viewModel.language == .fr ? "Haut droite" : "Top right"
        case .topLeft: viewModel.language == .fr ? "Haut gauche" : "Top left"
        case .center: viewModel.language == .fr ? "Centre" : "Center"
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                .foregroundStyle(.primary)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct KeyboardArrowIcon: View {
    enum Axis {
        case horizontal
        case vertical
    }

    let axis: Axis

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary)
            if axis == .horizontal {
                HStack(spacing: 1) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
            } else {
                VStack(spacing: -2) {
                    Image(systemName: "chevron.up")
                    Image(systemName: "chevron.down")
                }
            }
        }
        .font(.system(size: 12, weight: .bold))
        .frame(width: 24, height: 24)
    }
}

struct DropZone: View {
    let title: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .overlay {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30))
                    Text(title)
                }
                .foregroundStyle(.secondary)
            }
    }
}

struct ControlRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(width: 115, alignment: .leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PreviewBox: View {
    let title: String
    let image: NSImage?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            ZStack {
                Rectangle().fill(.quaternary)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }
}

struct FocusMarkingPreviewBox: View {
    let title: String
    let image: NSImage?
    let annotations: [FocusAnnotation]
    let tool: FocusTool
    let onPoint: (CGPoint, CGSize) -> Void
    let onZone: (CGRect, CGSize) -> Void
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.caption)
                if tool != .none {
                    Image(systemName: tool == .point ? "scope" : "rectangle.dashed")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            GeometryReader { proxy in
                let imageSize = image?.size ?? .zero
                let frame = Self.imageFrame(imageSize: imageSize, container: proxy.size)
                ZStack {
                    Rectangle().fill(.quaternary)
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                        ForEach(annotations) { annotation in
                            let rect = Self.viewRect(for: annotation.rect, imageSize: imageSize, imageFrame: frame)
                            if annotation.kind == .point {
                                Circle()
                                    .stroke(.yellow, lineWidth: 3)
                                    .frame(width: max(14, rect.width), height: max(14, rect.height))
                                    .position(x: rect.midX, y: rect.midY)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.yellow, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                            }
                        }
                        if let dragStart, let dragCurrent, tool == .zone {
                            let rect = CGRect(
                                x: min(dragStart.x, dragCurrent.x),
                                y: min(dragStart.y, dragCurrent.y),
                                width: abs(dragCurrent.x - dragStart.x),
                                height: abs(dragCurrent.y - dragStart.y)
                            )
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .gesture(tool == .none ? nil : DragGesture(minimumDistance: tool == .point ? 0 : 4)
                    .onChanged { value in
                        guard frame.contains(value.startLocation), frame.contains(value.location) else { return }
                        if tool == .zone {
                            dragStart = value.startLocation
                            dragCurrent = value.location
                        }
                    }
                    .onEnded { value in
                        defer {
                            dragStart = nil
                            dragCurrent = nil
                        }
                        guard imageSize.width > 1, imageSize.height > 1 else { return }
                        switch tool {
                        case .none:
                            return
                        case .point:
                            guard frame.contains(value.location) else { return }
                            onPoint(Self.imagePoint(for: value.location, imageSize: imageSize, imageFrame: frame), imageSize)
                        case .zone:
                            guard frame.contains(value.startLocation), frame.contains(value.location) else { return }
                            let start = Self.imagePoint(for: value.startLocation, imageSize: imageSize, imageFrame: frame)
                            let end = Self.imagePoint(for: value.location, imageSize: imageSize, imageFrame: frame)
                            onZone(CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            ), imageSize)
                        }
                    })
            }
            .frame(height: 280)
        }
        .frame(maxWidth: .infinity)
    }

    private static func imageFrame(imageSize: CGSize, container: CGSize) -> CGRect {
        guard imageSize.width > 1, imageSize.height > 1 else {
            return CGRect(origin: .zero, size: container).insetBy(dx: 6, dy: 6)
        }
        let maxSize = CGSize(width: max(1, container.width - 12), height: max(1, container.height - 12))
        let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func imagePoint(for location: CGPoint, imageSize: CGSize, imageFrame: CGRect) -> CGPoint {
        CGPoint(
            x: (location.x - imageFrame.minX) / imageFrame.width * imageSize.width,
            y: (location.y - imageFrame.minY) / imageFrame.height * imageSize.height
        )
    }

    private static func viewRect(for rect: CGRect, imageSize: CGSize, imageFrame: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + rect.minX / imageSize.width * imageFrame.width,
            y: imageFrame.minY + rect.minY / imageSize.height * imageFrame.height,
            width: rect.width / imageSize.width * imageFrame.width,
            height: rect.height / imageSize.height * imageFrame.height
        )
    }
}

struct DraggablePreviewBox: View {
    let title: String
    let sourceImage: NSImage?
    let renderedImage: NSImage?
    let decision: CropDecision?
    let imageSize: CGSize
    let aspectRatio: CGFloat
    let showRenderedPreview: Bool
    let onDragChanged: (CGSize, CGSize) -> Void
    let onDragEnded: () -> Void
    @State private var liveDrag: CGSize = .zero
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.caption)
            }
            GeometryReader { proxy in
                let frameSize = Self.instagramFrameSize(in: proxy.size, aspectRatio: aspectRatio)
                ZStack {
                    Rectangle().fill(.quaternary)
                    ZStack {
                        Rectangle().fill(.black.opacity(0.08))
                        if showRenderedPreview, liveDrag == .zero, let renderedImage {
                            Image(nsImage: renderedImage)
                                .resizable()
                                .scaledToFit()
                        } else if let sourceImage, let decision, imageSize.width > 1, imageSize.height > 1 {
                            let placement = Self.sourcePlacement(
                                imageSize: imageSize,
                                cropRect: decision.cropRect,
                                frameSize: frameSize
                            )
                            Image(nsImage: sourceImage)
                                .resizable()
                                .frame(width: placement.size.width, height: placement.size.height)
                                .position(placement.center)
                                .offset(liveDrag)
                        } else if let renderedImage {
                            Image(nsImage: renderedImage)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: frameSize.width, height: frameSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .gesture((sourceImage != nil && decision != nil) ? DragGesture()
                        .onChanged { value in
                            let delta = CGSize(
                                width: value.translation.width - lastTranslation.width,
                                height: value.translation.height - lastTranslation.height
                            )
                            lastTranslation = value.translation
                            liveDrag = value.translation
                            onDragChanged(delta, frameSize)
                        }
                        .onEnded { _ in
                            liveDrag = .zero
                            lastTranslation = .zero
                            onDragEnded()
                        } : nil)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 280)
        }
        .frame(maxWidth: .infinity)
    }

    private static func instagramFrameSize(in container: CGSize, aspectRatio: CGFloat) -> CGSize {
        let maxWidth = max(1, container.width - 12)
        let maxHeight = max(1, container.height - 12)
        if maxWidth / maxHeight > aspectRatio {
            return CGSize(width: maxHeight * aspectRatio, height: maxHeight)
        }
        return CGSize(width: maxWidth, height: maxWidth / aspectRatio)
    }

    private static func sourcePlacement(imageSize: CGSize, cropRect: CGRect, frameSize: CGSize) -> (size: CGSize, center: CGPoint) {
        let scale = max(frameSize.width / max(1, cropRect.width), frameSize.height / max(1, cropRect.height))
        let renderedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: -cropRect.minX * scale, y: -cropRect.minY * scale)
        return (
            size: renderedSize,
            center: CGPoint(x: origin.x + renderedSize.width / 2, y: origin.y + renderedSize.height / 2)
        )
    }
}
