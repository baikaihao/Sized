import AppKit
import Foundation

let targetBytes = 750 * 1024
let iconSizes = [16, 32, 64, 128, 256, 512, 1024]

enum IconMakerError: Error, LocalizedError {
    case missingInput
    case unreadableImage(String)
    case failedToCreateDirectory(String)
    case failedToRender(String)
    case failedToWrite(String)
    case iconutilFailed(String)
    case outputMissing(String)

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "No image path was provided."
        case .unreadableImage(let path):
            return "Could not read image: \(path)"
        case .failedToCreateDirectory(let path):
            return "Could not create directory: \(path)"
        case .failedToRender(let name):
            return "Could not render icon image: \(name)"
        case .failedToWrite(let path):
            return "Could not write image: \(path)"
        case .iconutilFailed(let message):
            return "iconutil failed: \(message)"
        case .outputMissing(let path):
            return "Output icon was not created: \(path)"
        }
    }
}

func shell(_ launchPath: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? "unknown error"
        throw IconMakerError.iconutilFailed(message)
    }
}

func renderIcon(source: NSImage, canvasSize: Int, contentScale: CGFloat, to url: URL) throws {
    let canvas = NSSize(width: canvasSize, height: canvasSize)
    let image = NSImage(size: canvas)
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvas).fill()

    let sourceSize = source.size
    let sourceAspect = sourceSize.width / max(sourceSize.height, 1)
    let maxContent = CGFloat(canvasSize) * contentScale

    let drawSize: NSSize
    if sourceAspect >= 1 {
        drawSize = NSSize(width: maxContent, height: maxContent / sourceAspect)
    } else {
        drawSize = NSSize(width: maxContent * sourceAspect, height: maxContent)
    }

    let drawRect = NSRect(
        x: (CGFloat(canvasSize) - drawSize.width) / 2,
        y: (CGFloat(canvasSize) - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
    )

    source.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconMakerError.failedToRender(url.lastPathComponent)
    }

    guard FileManager.default.createFile(atPath: url.path, contents: png) else {
        throw IconMakerError.failedToWrite(url.path)
    }
}

func makeIconset(from source: NSImage, at iconsetURL: URL, contentScale: CGFloat, maxBaseSize: Int) throws {
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: iconsetURL)
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

    for size in iconSizes where size <= maxBaseSize {
        let oneXURL = iconsetURL.appendingPathComponent("icon_\(size)x\(size).png")
        try renderIcon(source: source, canvasSize: size, contentScale: contentScale, to: oneXURL)

        let twoXSize = size * 2
        if twoXSize <= 1024 && twoXSize <= maxBaseSize {
            let twoXURL = iconsetURL.appendingPathComponent("icon_\(size)x\(size)@2x.png")
            try renderIcon(source: source, canvasSize: twoXSize, contentScale: contentScale, to: twoXURL)
        }
    }
}

func fileSize(_ url: URL) -> Int {
    let values = try? url.resourceValues(forKeys: [.fileSizeKey])
    return values?.fileSize ?? Int.max
}

func outputURL(for inputURL: URL) -> URL {
    let folder = inputURL.deletingLastPathComponent()
    let base = inputURL.deletingPathExtension().lastPathComponent
    return folder.appendingPathComponent("\(base)-750kb-icon.icns")
}

func makeIcon(inputPath: String) throws {
    let inputURL = URL(fileURLWithPath: inputPath)
    guard let source = NSImage(contentsOf: inputURL) else {
        throw IconMakerError.unreadableImage(inputPath)
    }

    let output = outputURL(for: inputURL)
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("SizedIconMaker-\(UUID().uuidString)", isDirectory: true)
    let iconset = temporaryRoot.appendingPathComponent("Generated.iconset", isDirectory: true)

    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

    let baseSizes = [1024, 512, 256, 128]
    let contentScales: [CGFloat] = [0.92, 0.86, 0.80, 0.74, 0.68]

    var producedOutput = false

    for baseSize in baseSizes {
        for contentScale in contentScales {
            try makeIconset(from: source, at: iconset, contentScale: contentScale, maxBaseSize: baseSize)
            try? FileManager.default.removeItem(at: output)
            try shell("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", output.path])

            guard FileManager.default.fileExists(atPath: output.path) else {
                throw IconMakerError.outputMissing(output.path)
            }

            producedOutput = true
            if fileSize(output) <= targetBytes {
                return
            }
        }
    }

    if !producedOutput {
        throw IconMakerError.outputMissing(output.path)
    }
}

do {
    guard CommandLine.arguments.count > 1 else {
        throw IconMakerError.missingInput
    }

    for input in CommandLine.arguments.dropFirst() {
        try makeIcon(inputPath: input)
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
