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

            Text("Images")
                .font(.headline)
            List(selection: $viewModel.selectedID) {
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
                Text("JPEG")
                Slider(value: $viewModel.jpegQuality, in: 0.5...1.0)
                Toggle("Debug boxes", isOn: $viewModel.debugOverlay)
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
                Button("Appliquer correction manuelle") {
                    viewModel.applyManualCrop()
                }
                .disabled(viewModel.previewDecision == nil)
            }
            HStack(spacing: 16) {
                PreviewBox(title: "Avant", image: viewModel.selectedImage?.preview)
                PreviewBox(title: "Apres", image: viewModel.afterPreview)
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
