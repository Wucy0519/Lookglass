import AppKit

enum ModelKind {
    case woman, man, neutral
}

let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

func save(_ name: String, _ image: NSImage) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("无法写出 \(name)\n", stderr)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
}

func render(_ kind: ModelKind) -> NSImage {
    let size = NSSize(width: 900, height: 1200)
    return NSImage(size: size, flipped: true) { rect in
        let warm = kind == .woman
        let cool = kind == .man
        let top = NSColor(srgbRed: warm ? 0.95 : 0.93, green: cool ? 0.93 : 0.91, blue: cool ? 0.91 : 0.86, alpha: 1)
        let bottom = NSColor(srgbRed: warm ? 0.86 : 0.84, green: cool ? 0.86 : 0.82, blue: cool ? 0.84 : 0.76, alpha: 1)
        NSGradient(colors: [top, bottom])?.draw(in: rect, angle: -90)
        let ground = NSColor(srgbRed: 0.2, green: 0.16, blue: 0.13, alpha: 0.08)
        ground.setFill()
        NSBezierPath(ovalIn: NSRect(x: 250, y: 1048, width: 400, height: 46)).fill()

        let skin = NSColor(srgbRed: 0.90, green: 0.76, blue: 0.66, alpha: 1)
        let hair = NSColor(srgbRed: 0.16, green: 0.13, blue: 0.12, alpha: 1)
        let shirt = NSColor(srgbRed: 0.97, green: 0.95, blue: 0.92, alpha: 1)
        let seam = NSColor(srgbRed: 0.80, green: 0.76, blue: 0.71, alpha: 1)
        let pants = NSColor(srgbRed: 0.18, green: 0.20, blue: 0.23, alpha: 1)
        let shoe = NSColor(srgbRed: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        let cx: CGFloat = 450
        let shoulder: CGFloat = kind == .man ? 280 : (kind == .neutral ? 250 : 236)

        func round(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
        func oval(_ rect: NSRect, _ color: NSColor) {
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }

        if kind == .woman {
            oval(NSRect(x: cx - 118, y: 150, width: 236, height: 300), hair)
            round(NSRect(x: cx - 150, y: 250, width: 78, height: 340), 36, hair)
            round(NSRect(x: cx + 72, y: 250, width: 78, height: 390), 36, hair)
        } else if kind == .neutral {
            oval(NSRect(x: cx - 108, y: 156, width: 216, height: 250), hair)
            round(NSRect(x: cx - 132, y: 230, width: 70, height: 210), 32, hair)
            round(NSRect(x: cx + 62, y: 230, width: 70, height: 210), 32, hair)
        } else {
            oval(NSRect(x: cx - 96, y: 148, width: 192, height: 150), hair)
        }

        round(NSRect(x: cx - 28, y: 318, width: 56, height: 54), 16, skin)
        round(NSRect(x: cx - shoulder / 2 - 18, y: 390, width: 52, height: 300), 24, skin)
        round(NSRect(x: cx + shoulder / 2 - 34, y: 390, width: 52, height: 300), 24, skin)
        oval(NSRect(x: cx - shoulder / 2 - 16, y: 670, width: 48, height: 36), skin)
        oval(NSRect(x: cx + shoulder / 2 - 32, y: 670, width: 48, height: 36), skin)

        round(NSRect(x: cx - shoulder / 2, y: 360, width: shoulder, height: 290), 46, shirt)
        oval(NSRect(x: cx - 78, y: 168, width: 156, height: 188), skin)
        if kind == .man {
            oval(NSRect(x: cx - 22, y: 250, width: 22, height: 28), skin)
            oval(NSRect(x: cx + 4, y: 250, width: 22, height: 28), skin)
        }

        seam.setStroke()
        let placket = NSBezierPath()
        placket.lineWidth = 3
        placket.move(to: NSPoint(x: cx, y: 390))
        placket.line(to: NSPoint(x: cx, y: 620))
        placket.stroke()
        let collar = NSBezierPath()
        collar.lineWidth = 4
        collar.move(to: NSPoint(x: cx - 36, y: 392))
        collar.line(to: NSPoint(x: cx, y: 430))
        collar.line(to: NSPoint(x: cx + 36, y: 392))
        collar.stroke()

        round(NSRect(x: cx - 108, y: 600, width: 216, height: 90), 30, pants)
        round(NSRect(x: cx - 102, y: 640, width: 86, height: 390), 24, pants)
        round(NSRect(x: cx + 16, y: 640, width: 86, height: 390), 24, pants)
        round(NSRect(x: cx - 108, y: 1008, width: 96, height: 28), 8, shoe)
        round(NSRect(x: cx + 12, y: 1008, width: 96, height: 28), 8, shoe)

        let feature = NSColor(srgbRed: 0.25, green: 0.18, blue: 0.16, alpha: 0.85)
        feature.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 34, y: 236, width: 12, height: 8)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx + 22, y: 236, width: 12, height: 8)).fill()
        let mouth = NSBezierPath()
        mouth.lineWidth = 2
        NSColor(srgbRed: 0.70, green: 0.42, blue: 0.38, alpha: 1).setStroke()
        mouth.move(to: NSPoint(x: cx - 12, y: 292))
        mouth.line(to: NSPoint(x: cx + 12, y: 292))
        mouth.stroke()
        return true
    }
}

try save("model-woman.png", render(.woman))
try save("model-man.png", render(.man))
try save("model-neutral.png", render(.neutral))
