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
    samplesPerPixel: 3,
    hasAlpha: false,
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
    fatalError("Could not encode AppIcon.png")
}
try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: output).deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try data.write(to: URL(fileURLWithPath: output), options: .atomic)
print("Generated opaque 1024x1024 iOS AppIcon")
