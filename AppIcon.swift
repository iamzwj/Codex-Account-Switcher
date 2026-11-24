import AppKit

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
do {
    let tile = NSBezierPath(roundedRect: NSRect(x: 104, y: 104, width: 816, height: 816), xRadius: 190, yRadius: 190)
    NSColor(srgbRed: 0.08, green: 0.13, blue: 0.22, alpha: 1).setFill()
    tile.fill()
    NSColor(srgbRed: 0.34, green: 0.86, blue: 1, alpha: 1).setStroke()
    for (from, to, y, direction) in [(310.0, 710.0, 610.0, 1.0), (710.0, 310.0, 414.0, -1.0)] {
        let arrow = NSBezierPath()
        arrow.lineWidth = 56
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: from, y: y))
        arrow.line(to: NSPoint(x: to, y: y))
        arrow.move(to: NSPoint(x: to - 107 * direction, y: y + 92))
        arrow.line(to: NSPoint(x: to, y: y))
        arrow.line(to: NSPoint(x: to - 107 * direction, y: y - 92))
        arrow.stroke()
    }
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
