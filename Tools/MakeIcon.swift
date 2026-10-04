import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    NSColor(srgbRed: 0.965, green: 0.945, blue: 0.918, alpha: 1).setFill()
    rect.fill()
    let disc = NSBezierPath(ovalIn: NSRect(x: 176, y: 176, width: 672, height: 672))
    NSColor(srgbRed: 0.145, green: 0.125, blue: 0.110, alpha: 1).setFill()
    disc.fill()
    let ink = NSColor(srgbRed: 0.965, green: 0.945, blue: 0.918, alpha: 1)
    ink.setStroke()
    let hanger = NSBezierPath()
    hanger.lineWidth = 46
    hanger.lineCapStyle = .round
    hanger.lineJoinStyle = .round
    hanger.move(to: NSPoint(x: 512, y: 690))
    hanger.appendArc(withCenter: NSPoint(x: 512, y: 690), radius: 54, startAngle: 180, endAngle: 0, clockwise: true)
    hanger.move(to: NSPoint(x: 512, y: 636))
    hanger.line(to: NSPoint(x: 512, y: 590))
    hanger.move(to: NSPoint(x: 300, y: 470))
    hanger.line(to: NSPoint(x: 512, y: 590))
    hanger.line(to: NSPoint(x: 724, y: 470))
    hanger.move(to: NSPoint(x: 332, y: 430))
    hanger.line(to: NSPoint(x: 692, y: 430))
    hanger.stroke()
    return true
}
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("无法生成图标\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
