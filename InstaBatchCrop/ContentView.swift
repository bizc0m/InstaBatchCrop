import AppKit
import InstaBatchCropCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 360, idealWidth: 420)
            rightPane
                .frame(minWidth: 650)
        }
        .padding(16)
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
                Button("Nettoyer la file") {
                    viewModel.clearQueue()
                }
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
    }

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            controls
            Divider()
            preview
            Divider()
            report
        }
        .padding(.leading, 12)
    }

    private var controls: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            GridRow {
                Text("Formats")
                HStack {
                    ForEach(OutputFormat.allCases) { format in
                        Toggle(format.displayName, isOn: Binding(
                            get: { viewModel.selectedFormats.contains(format) },
                            set: { enabled in viewModel.setFormat(format, enabled: enabled) }
                        ))
                    }
                }
            }
            GridRow {
                Text("Mode")
                Picker("", selection: $viewModel.cropMode) {
                    ForEach(CropMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            GridRow {
                Text("Secours")
                Picker("", selection: $viewModel.fallbackMode) {
                    ForEach(FallbackMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            GridRow {
                Text("Marge")
                Slider(value: $viewModel.margin, in: 0.02...0.35)
                Text("\(Int(viewModel.margin * 100))%")
            }
            GridRow {
                Text("Export")
                Picker("", selection: $viewModel.exportType) {
                    ForEach(ExportFileType.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Metadonnees", isOn: $viewModel.preserveMetadata)
            }
            GridRow {
                Text("Compression")
                Slider(value: $viewModel.jpegQuality, in: 0.5...1.0)
                Toggle("Debug boxes", isOn: $viewModel.debugOverlay)
            }
            GridRow {
                Text("Watermark")
                Toggle("Actif", isOn: $viewModel.watermarkEnabled)
                TextField("Texte", text: $viewModel.watermarkText)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Position")
                Picker("", selection: $viewModel.watermarkPosition) {
                    ForEach(WatermarkPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                HStack {
                    Text("Opacite")
                    Slider(value: $viewModel.watermarkOpacity, in: 0.05...1.0)
                }
            }
            GridRow {
                Text("Watermark taille")
                Slider(value: $viewModel.watermarkSize, in: 12...120)
                HStack {
                    Text("Marge")
                    Slider(value: $viewModel.watermarkMargin, in: 0...160)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Apercu avant / apres")
                    .font(.headline)
                Spacer()
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
                Button("Appliquer correction manuelle") {
                    viewModel.applyManualCrop()
                }
                .disabled(viewModel.previewDecision == nil)
            }
            HStack(spacing: 16) {
                PreviewBox(title: "Avant", image: viewModel.selectedImage?.preview)
                DraggablePreviewBox(
                    title: "Apres",
                    image: viewModel.afterPreview,
                    isHandEnabled: viewModel.handToolEnabled,
                    dragOffset: $viewModel.previewDragOffset
                ) { translation, size in
                    Task { await viewModel.applyPreviewDrag(translation, previewSize: size) }
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
                    Text("Y")
                    Slider(value: $viewModel.manualOffsetY, in: -1...1)
                    Text("Zoom")
                    Slider(value: $viewModel.manualZoom, in: 0.8...1.6)
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
    }
}

struct DraggablePreviewBox: View {
    let title: String
    let image: NSImage?
    let isHandEnabled: Bool
    @Binding var dragOffset: CGSize
    let onDragEnded: (CGSize, CGSize) -> Void

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
                ZStack {
                    Rectangle().fill(.quaternary)
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .offset(dragOffset)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .gesture(isHandEnabled ? DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        onDragEnded(value.translation, proxy.size)
                    } : nil)
            }
            .frame(height: 280)
        }
    }
}
