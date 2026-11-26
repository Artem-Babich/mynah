// Draws the Mynah app icon (a mynah singing sound waves) and writes resources/AppIcon.icns.
//   swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Mynah-\(UUID().uuidString).iconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Master artwork on a 1024 canvas (macOS template: 824 pt body, 100 pt margin).
func drawIcon() {
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.30)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0xFF6A1A).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0xFFB547), ending: color(0xFF6A1A))!.draw(in: body, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    let dx: CGFloat = -70

    // Bird: head + body + tail, all inside the rounded square.
    let bird = NSBezierPath()
    bird.appendOval(in: NSRect(x: 350 + dx, y: 400, width: 330, height: 330))
    bird.appendOval(in: NSRect(x: 255 + dx, y: 190, width: 390, height: 410))
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 310 + dx, y: 270))
    tail.curve(to: NSPoint(x: 268 + dx, y: 205), controlPoint1: NSPoint(x: 290 + dx, y: 245), controlPoint2: NSPoint(x: 278 + dx, y: 222))
    tail.line(to: NSPoint(x: 360 + dx, y: 222))
    tail.close()
    bird.append(tail)
    bird.windingRule = .nonZero
    color(0x1F1A2E).setFill()
    bird.fill()

    // Beak
    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: 660 + dx, y: 606))
    beak.curve(to: NSPoint(x: 808 + dx, y: 556), controlPoint1: NSPoint(x: 735 + dx, y: 606), controlPoint2: NSPoint(x: 790 + dx, y: 578))
    beak.curve(to: NSPoint(x: 664 + dx, y: 528), controlPoint1: NSPoint(x: 770 + dx, y: 536), controlPoint2: NSPoint(x: 710 + dx, y: 522))
    beak.close()
    color(0xFFE066).setFill()
    beak.fill()

    // Yellow eye patch (mynah wattle), eye, pupil
    color(0xFFC93C).setFill()
    NSBezierPath(ovalIn: NSRect(x: 552 + dx, y: 566, width: 92, height: 62)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 570 + dx, y: 594, width: 44, height: 44)).fill()
    color(0x111018).setFill()
    NSBezierPath(ovalIn: NSRect(x: 584 + dx, y: 604, width: 22, height: 22)).fill()

    // Sound waves
    let center = NSPoint(x: 760 + dx, y: 560)
    for i in 0..<3 {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: 70 + CGFloat(i) * 56, startAngle: -36, endAngle: 36)
        arc.lineWidth = 26
        arc.lineCapStyle = .round
        NSColor.white.withAlphaComponent(1 - CGFloat(i) * 0.22).setStroke()
        arc.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(size) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try png(size: 1024).write(to: root.appendingPathComponent("resources/AppIcon-1024.png"))

let out = root.appendingPathComponent("resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed")
