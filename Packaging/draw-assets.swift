import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}
func canvas(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
func save(_ bitmap: NSBitmapImageRep, _ path: URL) throws {
    try bitmap.representation(using: .png, properties: [:])!.write(to: path)
}
func label(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight, foreground: NSColor) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    (text as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: foreground, .paragraphStyle: style])
}
func icon(_ size: Int) -> NSBitmapImageRep {
    canvas(size, size) {
        NSGraphicsContext.current?.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        let outer = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 196, yRadius: 196)
        let shadow = NSShadow(); shadow.shadowColor = color(0.07, 0.16, 0.3, 0.2); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        color(0.96, 0.98, 1).setFill(); outer.fill(); NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: color(1, 1, 1), ending: color(0.88, 0.94, 1))!.draw(in: outer, angle: -65)
        let terminal = NSBezierPath(roundedRect: NSRect(x: 164, y: 218, width: 696, height: 602), xRadius: 90, yRadius: 90)
        NSGradient(starting: color(0.15, 0.58, 0.98), ending: color(0.08, 0.28, 0.67))!.draw(in: terminal, angle: -70)
        color(1, 1, 1, 0.5).setFill()
        for x in [CGFloat(226), 270, 314] { NSBezierPath(ovalIn: NSRect(x: x, y: 746, width: 20, height: 20)).fill() }
        let prompt = NSBezierPath(); prompt.move(to: NSPoint(x: 290, y: 626)); prompt.line(to: NSPoint(x: 407, y: 516)); prompt.line(to: NSPoint(x: 290, y: 406)); prompt.lineWidth = 42; prompt.lineCapStyle = .round; prompt.lineJoinStyle = .round
        NSColor.white.setStroke(); prompt.stroke()
        let underscore = NSBezierPath(); underscore.move(to: NSPoint(x: 478, y: 410)); underscore.line(to: NSPoint(x: 635, y: 410)); underscore.lineWidth = 42; underscore.lineCapStyle = .round; underscore.stroke()
        color(0.18, 0.73, 0.49).setFill(); NSBezierPath(ovalIn: NSRect(x: 668, y: 138, width: 222, height: 222)).fill()
        let check = NSBezierPath(); check.move(to: NSPoint(x: 724, y: 249)); check.line(to: NSPoint(x: 766, y: 207)); check.line(to: NSPoint(x: 837, y: 285)); check.lineWidth = 23; check.lineCapStyle = .round; check.lineJoinStyle = .round; NSColor.white.setStroke(); check.stroke()
    }
}

let iconset = destination.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try save(icon(size), iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try save(icon(size * 2), iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try save(icon(512), destination.appendingPathComponent("AppIcon-preview.png"))

func background() {
    let full = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 900, height: 540))
    NSGradient(starting: color(0.91, 0.96, 0.99), ending: color(0.985, 0.99, 1))!.draw(in: full, angle: -35)
    label("安装 Mac Env Assistant", rect: NSRect(x: 0, y: 443, width: 900, height: 38), size: 25, weight: .semibold, foreground: color(0.18, 0.23, 0.3))
    label("将应用拖入 Applications 文件夹", rect: NSRect(x: 0, y: 409, width: 900, height: 28), size: 15, weight: .regular, foreground: color(0.42, 0.48, 0.55))
    let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 390, y: 265)); arrow.line(to: NSPoint(x: 510, y: 265)); arrow.move(to: NSPoint(x: 483, y: 292)); arrow.line(to: NSPoint(x: 510, y: 265)); arrow.line(to: NSPoint(x: 483, y: 238)); arrow.lineWidth = 7; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; color(0.37, 0.60, 0.78, 0.65).setStroke(); arrow.stroke()
    label("按需配置 · 保留已有环境", rect: NSRect(x: 0, y: 53, width: 900, height: 25), size: 13, weight: .regular, foreground: color(0.52, 0.58, 0.64))
}
let wallpaper = canvas(1800, 1080) {
    NSGraphicsContext.current?.cgContext.scaleBy(x: 2, y: 2)
    background()
}
wallpaper.size = NSSize(width: 900, height: 540)
try save(wallpaper, destination.appendingPathComponent("background.png"))

let preview = canvas(1800, 1080) {
    NSGraphicsContext.current?.cgContext.scaleBy(x: 2, y: 2)
    background()
    NSImage(cgImage: icon(256).cgImage!, size: NSSize(width: 256, height: 256)).draw(in: NSRect(x: 158, y: 201, width: 134, height: 134))
    NSWorkspace.shared.icon(forFile: "/Applications").draw(in: NSRect(x: 608, y: 201, width: 134, height: 134))
    label("MacEnvAssistant", rect: NSRect(x: 95, y: 158, width: 260, height: 29), size: 19, weight: .regular, foreground: color(0.2, 0.23, 0.27))
    label("Applications", rect: NSRect(x: 545, y: 158, width: 260, height: 29), size: 19, weight: .regular, foreground: color(0.2, 0.23, 0.27))
}
try save(preview, destination.appendingPathComponent("DMG-layout-preview.png"))
