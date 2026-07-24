import AppKit
import InstaBatchCropCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftPane
                .frame(width: 300)
                .layoutPriority(1)
            Divider()
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(minWidth: 1060, minHeight: 760)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers)
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Choisir fichiers") { viewModel.selectFiles() }
                Button("Choisir dossier") { viewModel.selectFolder() }
            }

            DropZone()
                .frame(height: 110)

            HStack {
                Text("Images")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.removeSelectedImages()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Retirer les images selectionnees")
                .disabled(viewModel.selectedIDs.isEmpty)
                Button("Vider") {
                    viewModel.clearQueue()
                }
                .help("Nettoyer toute la file")
                .disabled(viewModel.images.isEmpty)
            }
            List(selection: $viewModel.selectedIDs) {
                ForEach(viewModel.images) { image in
                    HStack {
                        if let preview = image.preview {
                            Image(nsImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading) {
                            Text(image.url.lastPathComponent)
                                .lineLimit(1)
                            Text(image.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(image.id)
                }
            }

            ProgressView(value: viewModel.progress)
            Button("Traiter toutes les photos") {
                Task { await viewModel.processAll() }
            }
            .disabled(viewModel.images.isEmpty || viewModel.selectedFormats.isEmpty || viewModel.isProcessing)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    private var rightPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                Divider()
                preview
                Divider()
                report
                    .frame(minHeight: 180)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow("Formats") {
                HStack {
                    ForEach(OutputFormat.allCases) { format in
                        Toggle(format.displayName, isOn: Binding(
                            get: { viewModel.selectedFormats.contains(format) },
                            set: { enabled in viewModel.setFormat(format, enabled: enabled) }
                        ))
                    }
                }
            }
            ControlRow("Mode") {
                Picker("", selection: $viewModel.cropMode) {
                    ForEach(CropMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 320, maxWidth: 460)
            }
            ControlRow("Secours") {
                Picker("", selection: $viewModel.fallbackMode) {
                    ForEach(FallbackMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 420, maxWidth: 500)
            }
            ControlRow("Marge") {
                Slider(value: $viewModel.margin, in: 0.02...0.35)
                    .frame(minWidth: 120, maxWidth: 360)
                Text("\(Int(viewModel.margin * 100))%")
                    .frame(width: 48, alignment: .trailing)
            }
            ControlRow("Export") {
                Picker("", selection: $viewModel.exportType) {
                    ForEach(ExportFileType.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 230)
                Toggle("Metadonnees", isOn: $viewModel.preserveMetadata)
            }
            ControlRow("Compression") {
                Slider(value: $viewModel.jpegQuality, in: 0.5...1.0)
                    .frame(minWidth: 120, maxWidth: 340)
                Toggle("Debug boxes", isOn: $viewModel.debugOverlay)
            }
            ControlRow("Watermark") {
                Toggle("Actif", isOn: $viewModel.watermarkEnabled)
                TextField("Texte", text: Binding(
                    get: { viewModel.watermarkText },
                    set: { viewModel.updateWatermarkText($0) }
                ))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 140, maxWidth: 260)
                ColorPicker("", selection: Binding(
                    get: { viewModel.watermarkColor },
                    set: { viewModel.updateWatermarkColor($0) }
                ))
                    .labelsHidden()
                    .frame(width: 44)
                Button("Logo") {
                    viewModel.selectWatermarkImage()
                }
                .help("Choisir une image watermark, PNG transparent recommande")
                Button {
                    viewModel.clearWatermarkImage()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Retirer le logo watermark")
                .disabled(viewModel.watermarkImageURL == nil)
            }
            if let logoName = viewModel.watermarkImageURL?.lastPathComponent {
                ControlRow("Logo actif") {
                    Text(logoName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            ControlRow("Position") {
                Picker("", selection: $viewModel.watermarkPosition) {
                    ForEach(WatermarkPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                HStack {
                    Text("Opacite")
                    Slider(value: $viewModel.watermarkOpacity, in: 0.05...1.0)
                }
                .frame(minWidth: 160, maxWidth: 260)
            }
            ControlRow("Taille watermark") {
                Slider(value: $viewModel.watermarkSize, in: 12...120)
                    .frame(minWidth: 120, maxWidth: 240)
                HStack {
                    Text("Marge")
                    Slider(value: $viewModel.watermarkMargin, in: 0...160)
                }
                .frame(minWidth: 120, maxWidth: 240)
            }
        }
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

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apercu avant / apres")
                .font(.headline)
            HStack(spacing: 10) {
                Button("Generer apercu") {
                    Task { await viewModel.generatePreview() }
                }
                .disabled(viewModel.selectedImage == nil)
                Button {
                    viewModel.handToolEnabled.toggle()
                } label: {
                    Image(systemName: "hand.draw")
                }
                .help("Deplacer le cadrage dans l'apercu apres")
                .buttonStyle(.bordered)
                Button("Appliquer correction") {
                    viewModel.applyManualCrop()
                }
                .help("Appliquer la correction manuelle au batch")
                .disabled(viewModel.previewDecision == nil)
                Spacer(minLength: 0)
            }
            HStack(spacing: 16) {
                PreviewBox(title: "Avant", image: viewModel.selectedImage?.preview)
                DraggablePreviewBox(
                    title: "Apres",
                    sourceImage: viewModel.selectedImage?.preview,
                    renderedImage: viewModel.afterPreview,
                    decision: viewModel.previewDecision,
                    imageSize: viewModel.previewImageSize,
                    isHandEnabled: viewModel.handToolEnabled,
                    aspectRatio: viewModel.previewFormat.aspectRatio
                ) { translation, size in
                    viewModel.isDraggingPreview = true
                    viewModel.applyPreviewDrag(translation, previewSize: size)
                } onDragEnded: {
                    viewModel.finishPreviewDrag()
                }
            }
            if let decision = viewModel.previewDecision {
                Text("Score \(String(format: "%.2f", Double(decision.score))) - \(decision.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Grid(alignment: .leading) {
                GridRow {
                    Text("X")
                    Slider(value: $viewModel.manualOffsetX, in: -1...1)
                        .frame(minWidth: 120, maxWidth: 190)
                    Text("Y")
                    Slider(value: $viewModel.manualOffsetY, in: -1...1)
                        .frame(minWidth: 120, maxWidth: 190)
                    Text("Zoom")
                    Slider(value: $viewModel.manualZoom, in: 0.8...1.6)
                        .frame(minWidth: 120, maxWidth: 190)
                }
            }
        }
    }

    private var report: some View {
        VStack(alignment: .leading) {
            Text("Rapport")
                .font(.headline)
            List(viewModel.results) { result in
                HStack {
                    Text(result.status)
                        .frame(width: 72, alignment: .leading)
                    Text(result.inputURL.lastPathComponent)
                        .lineLimit(1)
                    Text(result.format.displayName)
                    Text(result.message)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct DropZone: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .overlay {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30))
                    Text("Glisser-deposer des photos")
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

struct DraggablePreviewBox: View {
    let title: String
    let sourceImage: NSImage?
    let renderedImage: NSImage?
    let decision: CropDecision?
    let imageSize: CGSize
    let isHandEnabled: Bool
    let aspectRatio: CGFloat
    let onDragChanged: (CGSize, CGSize) -> Void
    let onDragEnded: () -> Void
    @State private var liveDrag: CGSize = .zero
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.caption)
                if isHandEnabled {
                    Image(systemName: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            GeometryReader { proxy in
                let frameSize = Self.instagramFrameSize(in: proxy.size, aspectRatio: aspectRatio)
                ZStack {
                    Rectangle().fill(.quaternary)
                    ZStack {
                        Rectangle().fill(.black.opacity(0.08))
                        if let sourceImage, let decision, imageSize.width > 1, imageSize.height > 1 {
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
                    .overlay {
                        if isHandEnabled {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                                .offset(liveDrag)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(isHandEnabled ? DragGesture()
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
