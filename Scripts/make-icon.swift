// Draws Carafe's app icon: a wine carafe whose contents show a four-pane window.
// Usage: swift Scripts/make-icon.swift <output.png>
import AppKit

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func fillGradient(_ top: CGColor, _ bottom: CGColor, from: CGFloat, to: CGFloat) {
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: from), end: CGPoint(x: 0, y: to),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// Background: the standard macOS rounded square with a soft drop shadow.
let tile = CGPath(
    roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
    cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.35))
ctx.addPath(tile)
ctx.setFillColor(color(0x1B1030))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tile)
ctx.clip()
fillGradient(color(0x3A2259), color(0x140B24), from: 924, to: 100)
ctx.restoreGState()

// Carafe silhouette: flared lip, narrow neck, wide body.
let carafe = CGMutablePath()
carafe.move(to: CGPoint(x: 440, y: 810))
carafe.addLine(to: CGPoint(x: 584, y: 810))
carafe.addCurve(to: CGPoint(x: 552, y: 750), control1: CGPoint(x: 572, y: 790), control2: CGPoint(x: 552, y: 775))
carafe.addLine(to: CGPoint(x: 552, y: 620))
carafe.addCurve(to: CGPoint(x: 732, y: 330), control1: CGPoint(x: 552, y: 520), control2: CGPoint(x: 732, y: 480))
carafe.addCurve(to: CGPoint(x: 652, y: 220), control1: CGPoint(x: 732, y: 262), control2: CGPoint(x: 704, y: 220))
carafe.addLine(to: CGPoint(x: 372, y: 220))
carafe.addCurve(to: CGPoint(x: 292, y: 330), control1: CGPoint(x: 320, y: 220), control2: CGPoint(x: 292, y: 262))
carafe.addCurve(to: CGPoint(x: 472, y: 620), control1: CGPoint(x: 292, y: 480), control2: CGPoint(x: 472, y: 520))
carafe.addLine(to: CGPoint(x: 472, y: 750))
carafe.addCurve(to: CGPoint(x: 440, y: 810), control1: CGPoint(x: 472, y: 775), control2: CGPoint(x: 452, y: 790))
carafe.closeSubpath()

// Glass, then the wine clipped to the glass.
ctx.addPath(carafe)
ctx.setFillColor(color(0xFFFFFF, 0.10))
ctx.fillPath()

ctx.saveGState()
ctx.addPath(carafe)
ctx.clip()
ctx.clip(to: CGRect(x: 0, y: 0, width: 1024, height: 450))
fillGradient(color(0xFF5C7A), color(0xB5123F), from: 450, to: 220)
// Four panes: the Windows these bottles hold.
let pane: CGFloat = 64, gap: CGFloat = 14
let origin = CGPoint(x: 512 - pane - gap / 2, y: 328 - pane - gap / 2)
ctx.setFillColor(color(0xFFFFFF, 0.92))
for row in 0..<2 {
    for column in 0..<2 {
        let rect = CGRect(
            x: origin.x + CGFloat(column) * (pane + gap), y: origin.y + CGFloat(row) * (pane + gap),
            width: pane, height: pane)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
    }
}
ctx.fillPath()
ctx.restoreGState()

// Glass outline and a highlight along the left shoulder.
ctx.addPath(carafe)
ctx.setStrokeColor(color(0xFFFFFF, 0.92))
ctx.setLineWidth(16)
ctx.setLineJoin(.round)
ctx.strokePath()

let highlight = CGMutablePath()
highlight.move(to: CGPoint(x: 350, y: 300))
highlight.addCurve(to: CGPoint(x: 420, y: 500), control1: CGPoint(x: 340, y: 380), control2: CGPoint(x: 385, y: 450))
ctx.addPath(highlight)
ctx.setStrokeColor(color(0xFFFFFF, 0.45))
ctx.setLineWidth(12)
ctx.setLineCap(.round)
ctx.strokePath()

let image = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try image.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
