import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift generate_brand_assets.swift <project-root>\n", stderr)
    exit(1)
}

let projectRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assetsURL = projectRoot.appendingPathComponent("GooseBattery/Assets.xcassets", isDirectory: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
}

func image(size: CGFloat, drawing: (CGRect) -> Void) -> NSImage {
    let pixelSize = NSSize(width: size, height: size)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    bitmap.size = pixelSize

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = CGRect(origin: .zero, size: pixelSize)
    drawing(rect)

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: pixelSize)
    image.addRepresentation(bitmap)
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GooseBattery.Branding", code: 1)
    }

    try data.write(to: url)
}

func roundedBattery(in rect: CGRect, lineWidth: CGFloat) {
    let body = NSBezierPath(roundedRect: rect, xRadius: rect.height * 0.22, yRadius: rect.height * 0.22)
    body.lineWidth = lineWidth
    body.stroke()

    let terminalRect = CGRect(
        x: rect.maxX + rect.width * 0.03,
        y: rect.midY - rect.height * 0.16,
        width: rect.width * 0.08,
        height: rect.height * 0.32
    )
    let terminal = NSBezierPath(roundedRect: terminalRect, xRadius: terminalRect.height * 0.4, yRadius: terminalRect.height * 0.4)
    terminal.fill()
}

func gooseMark(in rect: CGRect, monochrome: Bool) {
    let bodyColor = monochrome ? NSColor.black : color(247, 250, 255)
    let wingColor = monochrome ? NSColor.black : color(204, 227, 239)
    let beakColor = monochrome ? NSColor.black : color(247, 153, 44)
    let eyeColor = monochrome ? NSColor.clear : color(24, 28, 38, 0.85)

    let bodyRect = CGRect(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.22, width: rect.width * 0.48, height: rect.height * 0.34)
    bodyColor.setFill()
    NSBezierPath(ovalIn: bodyRect).fill()

    let wingRect = CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.24, width: rect.width * 0.28, height: rect.height * 0.18)
    wingColor.setFill()
    NSBezierPath(ovalIn: wingRect).fill()

    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.34))
    tail.line(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.45))
    tail.line(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.27))
    tail.close()
    bodyColor.setFill()
    tail.fill()

    NSGraphicsContext.saveGraphicsState()
    let neckRect = CGRect(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.34, width: rect.width * 0.12, height: rect.height * 0.36)
    let context = NSGraphicsContext.current!.cgContext
    context.translateBy(x: neckRect.midX, y: neckRect.midY)
    context.rotate(by: -.pi / 18.0)
    context.translateBy(x: -neckRect.midX, y: -neckRect.midY)
    bodyColor.setFill()
    NSBezierPath(roundedRect: neckRect, xRadius: neckRect.width * 0.5, yRadius: neckRect.width * 0.5).fill()
    NSGraphicsContext.restoreGraphicsState()

    let headRect = CGRect(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.62, width: rect.width * 0.18, height: rect.height * 0.18)
    bodyColor.setFill()
    NSBezierPath(ovalIn: headRect).fill()

    let beak = NSBezierPath()
    beak.move(to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.70))
    beak.line(to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.75))
    beak.line(to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.65))
    beak.close()
    beakColor.setFill()
    beak.fill()

    if !monochrome {
        eyeColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.70, width: rect.width * 0.03, height: rect.width * 0.03)).fill()
    }
}

func drawAppIcon(size: CGFloat) -> NSImage {
    image(size: size) { rect in
        let insetRect = rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035)
        let background = NSBezierPath(roundedRect: insetRect, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
        let gradient = NSGradient(colors: [
            color(12, 33, 34),
            color(18, 41, 59),
            color(58, 27, 74)
        ])!
        gradient.draw(in: background, angle: -45)

        color(84, 236, 214, 0.22).setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.width * 0.08, y: rect.height * 0.54, width: rect.width * 0.40, height: rect.width * 0.40)).fill()

        let batteryRect = CGRect(x: rect.width * 0.56, y: rect.height * 0.56, width: rect.width * 0.22, height: rect.height * 0.12)
        color(255, 255, 255, 0.20).setStroke()
        color(255, 255, 255, 0.20).setFill()
        roundedBattery(in: batteryRect, lineWidth: rect.width * 0.018)

        gooseMark(in: CGRect(x: rect.width * 0.12, y: rect.height * 0.12, width: rect.width * 0.68, height: rect.height * 0.68), monochrome: false)

        let spark = NSBezierPath()
        spark.move(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.48))
        spark.line(to: CGPoint(x: rect.width * 0.63, y: rect.height * 0.39))
        spark.line(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.39))
        spark.line(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.27))
        spark.line(to: CGPoint(x: rect.width * 0.76, y: rect.height * 0.40))
        spark.line(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.40))
        spark.close()
        color(109, 254, 210, 0.90).setFill()
        spark.fill()
    }
}

func drawLogo(size: CGFloat) -> NSImage {
    drawAppIcon(size: size)
}

func drawMenuBarIcon(size: CGFloat) -> NSImage {
    image(size: size) { rect in
        gooseMark(in: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.08), monochrome: true)

        NSColor.black.setStroke()
        NSColor.black.setFill()
        roundedBattery(
            in: CGRect(
                x: rect.width * 0.54,
                y: rect.height * 0.50,
                width: rect.width * 0.22,
                height: rect.height * 0.11
            ),
            lineWidth: max(1.0, rect.width * 0.05)
        )
    }
}

let iconOutputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconOutputs {
    try writePNG(drawAppIcon(size: size), to: assetsURL.appendingPathComponent("AppIcon.appiconset/\(name)"))
}

try writePNG(drawLogo(size: 1024), to: assetsURL.appendingPathComponent("GooseLogo.imageset/goose-logo.png"))
try writePNG(drawMenuBarIcon(size: 64), to: assetsURL.appendingPathComponent("MenuBarIcon.imageset/menu-bar-icon.png"))
