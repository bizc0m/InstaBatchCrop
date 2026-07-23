import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("TestPhotos", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

struct Scene {
    let name: String
    let size: CGSize
    let subjects: [CGRect]
}

let scenes = [
    Scene(name: "single-person-landscape", size: CGSize(width: 1600, height: 1000), subjects: [CGRect(x: 660, y: 260, width: 280, height: 520)]),
    Scene(name: "face-near-edge", size: CGSize(width: 1200, height: 900), subjects: [CGRect(x: 60, y: 120, width: 260, height: 420)]),
    Scene(name: "group", size: CGSize(width: 1800, height: 1200), subjects: [CGRect(x: 300, y: 340, width: 310, height: 620), CGRect(x: 1120, y: 320, width: 330, height: 650)]),
    Scene(name: "wide-object", size: CGSize(width: 1800, height: 900), subjects: [CGRect(x: 220, y: 340, width: 1360, height: 180)]),
    Scene(name: "empty", size: CGSize(width: 1200, height: 1200), subjects: [])
]

for scene in scenes {
    let image = NSImage(size: scene.size)
    image.lockFocus()
    NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.90, alpha: 1).setFill()
    CGRect(origin: .zero, size: scene.size).fill()
    NSColor(calibratedRed: 0.22, green: 0.28, blue: 0.34, alpha: 1).setStroke()
    for rect in scene.subjects {
        let body = NSBezierPath(roundedRect: rect, xRadius: 60, yRadius: 60)
        body.lineWidth = 8
        body.stroke()
        NSColor(calibratedRed: 0.66, green: 0.48, blue: 0.38, alpha: 1).setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX - 70, y: rect.minY + 30, width: 140, height: 140)).fill()
        NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: rect.minX + 35, y: rect.minY + 150, width: rect.width - 70, height: rect.height - 170), xRadius: 45, yRadius: 45).fill()
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
        fatalError("Cannot render \(scene.name)")
    }
    try data.write(to: output.appendingPathComponent("\(scene.name).jpg"))
}

print("Generated \(scenes.count) images in \(output.path)")
