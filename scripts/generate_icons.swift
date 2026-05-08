import AppKit

let svgPath = "other/AppIcon.svg"
let outputDir = "Sized/Assets.xcassets/AppIcon.appiconset"

let sizes: [(file: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let fm = FileManager.default
guard fm.fileExists(atPath: svgPath) else {
    print("ERROR: SVG not found at \(svgPath)")
    exit(1)
}

guard let svgImage = NSImage(contentsOfFile: svgPath) else {
    print("ERROR: Failed to load SVG")
    exit(1)
}

for (file, pixels) in sizes {
    let size = NSSize(width: pixels, height: pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(origin: .zero, size: size)
    svgImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: Failed to encode \(file)")
        exit(1)
    }

    let outputPath = "\(outputDir)/\(file)"
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✓ \(file) (\(pixels)×\(pixels))")
}

print("\nDone! All icons generated.")
