import AppKit
import Foundation

// Reuse the original upstream Tink art, and flatten to an opaque RGB PNG for iOS.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift prepare_icons.swift <input> <output>")
}
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: input) else {
    fatalError("Missing Tink logo: \(input)")
}
let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Cannot create RGB icon bitmap")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(srgbRed: 0.063, green: 0.106, blue: 0.192, alpha: 1).setFill()
rect.fill()
image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode intermediate AppIcon.png")
}
let outputURL = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
let tempDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDirectory) }
let rgbaURL = tempDirectory.appendingPathComponent("composited.png")
let jpegURL = tempDirectory.appendingPathComponent("opaque.jpg")
try data.write(to: rgbaURL)

func runSips(_ arguments: [String]) throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = arguments
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        fatalError("sips failed with exit code \(task.terminationStatus)")
    }
}
// JPEG strips the alpha channel; convert back to PNG for the asset catalog.
try runSips(["-s", "format", "jpeg", rgbaURL.path, "--out", jpegURL.path])
try runSips(["-s", "format", "png", jpegURL.path, "--out", outputURL.path])
print("Generated opaque RGB 1024x1024 iOS AppIcon")
