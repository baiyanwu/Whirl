#!/usr/bin/env swift
import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let scriptDirectory = scriptURL.deletingLastPathComponent()
let projectDirectory = scriptDirectory.deletingLastPathComponent()
let sourceDirectory = scriptDirectory.appendingPathComponent("icon_sources", isDirectory: true)
let appSourceURL = sourceDirectory.appendingPathComponent("app_icon_master.png")
let menuSourceURL = sourceDirectory.appendingPathComponent("menu_bar_icon_master.png")
let appOutputDirectory = projectDirectory
    .appendingPathComponent("Whirl/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let menuOutputDirectory = projectDirectory
    .appendingPathComponent("Whirl/Resources/Assets.xcassets/MenuBarIcon.imageset", isDirectory: true)

let appSizes = [16, 32, 64, 128, 256, 512, 1024]
let menuSizes = [18, 36]

enum IconGenerationError: LocalizedError {
    case missingSource(URL)
    case bitmapCreationFailed(Int)
    case pngEncodingFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingSource(let url):
            return "Missing icon source: \(url.path)"
        case .bitmapCreationFailed(let size):
            return "Unable to create \(size)x\(size) bitmap"
        case .pngEncodingFailed(let size):
            return "Unable to encode \(size)x\(size) PNG"
        }
    }
}

func loadImage(at url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw IconGenerationError.missingSource(url)
    }
    return image
}

func writePNG(size: Int, to url: URL, draw: (NSRect) -> Void) throws {
    guard let bitmap = NSBitmapImageRep(
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
    ) else {
        throw IconGenerationError.bitmapCreationFailed(size)
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.bitmapCreationFailed(size)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()
    draw(canvas)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed(size)
    }
    try data.write(to: url, options: .atomic)
}

func drawAspectFit(_ image: NSImage, in rect: NSRect) {
    let imageSize = image.size
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let drawRect = NSRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    image.draw(
        in: drawRect,
        from: NSRect(origin: .zero, size: imageSize),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}

let appSource = try loadImage(at: appSourceURL)
let menuSource = try loadImage(at: menuSourceURL)

try FileManager.default.createDirectory(at: appOutputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuOutputDirectory, withIntermediateDirectories: true)

for size in appSizes {
    try writePNG(size: size, to: appOutputDirectory.appendingPathComponent("icon_\(size).png")) { canvas in
        appSource.draw(
            in: canvas,
            from: NSRect(origin: .zero, size: appSource.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

for size in menuSizes {
    try writePNG(size: size, to: menuOutputDirectory.appendingPathComponent("menu_bar_\(size).png")) { canvas in
        let inset = CGFloat(size) / 18.0
        drawAspectFit(menuSource, in: canvas.insetBy(dx: inset, dy: inset))
    }
}

print("Generated Whirl app icon from app_icon_master.png")
print("Generated Whirl template menu icon from menu_bar_icon_master.png")
