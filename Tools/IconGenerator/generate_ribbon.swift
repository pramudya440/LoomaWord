import Cocoa
import CoreGraphics

func createLoomaRibbonIcon() -> NSImage {
    let size: CGFloat = 1024.0
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // ==========================================
    // 1. Drop Shadow for Squircle
    // ==========================================
    ctx.saveGState()
    let shadowColor = NSColor(red: 0.0, green: 0.0, blue: 0.03, alpha: 0.45).cgColor
    ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 36, color: shadowColor)

    let margin: CGFloat = 104.0
    let bodySize: CGFloat = 816.0
    let cornerRadius: CGFloat = 186.0
    let squircleRect = CGRect(x: margin, y: margin, width: bodySize, height: bodySize)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // ==========================================
    // 2. Base Squircle Surface with Clipping
    // ==========================================
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Background Gradient: Deep Nocturnal Obsidian
    let bgColors = [
        NSColor(red: 0.09, green: 0.11, blue: 0.19, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: 512, y: 1024 - margin),
        end: CGPoint(x: 512, y: margin),
        options: []
    )

    // Ambient radial glow behind the emblem
    let glowColors = [
        NSColor(red: 0.20, green: 0.32, blue: 0.75, alpha: 0.28).cgColor,
        NSColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 0.0).cgColor
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: 512, y: 512),
        startRadius: 20,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 360,
        options: []
    )

    // Inner Rim Highlight
    ctx.saveGState()
    ctx.setLineWidth(2.0)
    let rimColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.02).cgColor
    ] as CFArray
    let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 1.0])!
    ctx.addPath(squirclePath)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        rimGrad,
        start: CGPoint(x: 512, y: 1024 - margin),
        end: CGPoint(x: 512, y: margin),
        options: []
    )
    ctx.restoreGState()

    // ==========================================
    // 3. Central Emblem: The "L-W Continuous Weave"
    // ==========================================
    let ribbonWidth: CGFloat = 64.0

    // Construct the continuous L-W path with smooth curves
    let ribbonPath = CGMutablePath()

    // Start of 'L' at top-left
    ribbonPath.move(to: CGPoint(x: 310, y: 685))
    // Down to bottom-left corner of L
    ribbonPath.addLine(to: CGPoint(x: 310, y: 405))
    // Rounded corner of L
    ribbonPath.addArc(
        tangent1End: CGPoint(x: 310, y: 340),
        tangent2End: CGPoint(x: 375, y: 340),
        radius: 65
    )
    // Horizontal foot of L
    ribbonPath.addLine(to: CGPoint(x: 420, y: 340))
    // Turn up-right into the first ascent of W
    ribbonPath.addArc(
        tangent1End: CGPoint(x: 470, y: 340),
        tangent2End: CGPoint(x: 500, y: 390),
        radius: 50
    )
    // Ascend to W middle peak
    ribbonPath.addLine(to: CGPoint(x: 520, y: 550))
    // W middle peak curve
    ribbonPath.addArc(
        tangent1End: CGPoint(x: 535, y: 605),
        tangent2End: CGPoint(x: 565, y: 550),
        radius: 38
    )
    // Descend into W second valley
    ribbonPath.addLine(to: CGPoint(x: 605, y: 395))
    // W valley curve
    ribbonPath.addArc(
        tangent1End: CGPoint(x: 625, y: 340),
        tangent2End: CGPoint(x: 675, y: 375),
        radius: 46
    )
    // Ascend to W final top right
    ribbonPath.addLine(to: CGPoint(x: 715, y: 685))

    // 3a. Ribbon Drop Shadow (adds depth against dark squircle)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 24,
        color: NSColor(red: 0.05, green: 0.15, blue: 0.45, alpha: 0.55).cgColor
    )
    ctx.setLineWidth(ribbonWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(ribbonPath)
    ctx.setStrokeColor(NSColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 0.8).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 3b. Stroked Gradient Ribbon
    ctx.saveGState()
    ctx.setLineWidth(ribbonWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(ribbonPath)
    ctx.replacePathWithStrokedPath()
    ctx.clip()

    // Gradient: Cyan (#00F2FE) -> Azure (#2575FC) -> Purple (#7928CA) -> Sunset Rose (#FF0080)
    let ribbonColors = [
        NSColor(red: 0.00, green: 0.95, blue: 1.00, alpha: 1.0).cgColor, // Electric Cyan
        NSColor(red: 0.14, green: 0.45, blue: 0.98, alpha: 1.0).cgColor, // Azure
        NSColor(red: 0.55, green: 0.18, blue: 0.92, alpha: 1.0).cgColor, // Iris Violet
        NSColor(red: 1.00, green: 0.15, blue: 0.55, alpha: 1.0).cgColor  // Sunset Rose
    ] as CFArray
    let ribbonLocs: [CGFloat] = [0.0, 0.35, 0.70, 1.0]
    let ribbonGrad = CGGradient(colorsSpace: colorSpace, colors: ribbonColors, locations: ribbonLocs)!

    ctx.drawLinearGradient(
        ribbonGrad,
        start: CGPoint(x: 290, y: 685),
        end: CGPoint(x: 725, y: 685),
        options: []
    )

    // Inner subtle light sheen / glass tube reflection
    let sheenColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: 512, y: 700),
        end: CGPoint(x: 512, y: 320),
        options: []
    )
    ctx.restoreGState()

    // 4. Accent Translation Spark / Lumen
    // A crisp, brilliant 4-point diamond star placed at the apex of the W curve (535, 605)
    // or as a floating focal star at (x: 435, y: 550) inside the L opening
    let starX: CGFloat = 432
    let starY: CGFloat = 535
    ctx.saveGState()

    // Star Glow
    let starGlowColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85).cgColor,
        NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.35).cgColor,
        NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let starGlowGrad = CGGradient(colorsSpace: colorSpace, colors: starGlowColors, locations: [0.0, 0.4, 1.0])!
    ctx.drawRadialGradient(
        starGlowGrad,
        startCenter: CGPoint(x: starX, y: starY),
        startRadius: 0,
        endCenter: CGPoint(x: starX, y: starY),
        endRadius: 45,
        options: []
    )

    // 4-point Star Shape
    let starPath = CGMutablePath()
    let starR1: CGFloat = 26.0
    let starR2: CGFloat = 6.5
    for i in 0..<8 {
        let angle = CGFloat(i) * (.pi / 4.0) - (.pi / 2.0)
        let r = (i % 2 == 0) ? starR1 : starR2
        let pt = CGPoint(x: starX + r * cos(angle), y: starY + r * sin(angle))
        if i == 0 { starPath.move(to: pt) } else { starPath.addLine(to: pt) }
    }
    starPath.closeSubpath()

    ctx.addPath(starPath)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // End Squircle Clip
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

let icon = createLoomaRibbonIcon()
guard let tiffData = icon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = "dist/preview_ribbon.png"
try? pngData.write(to: URL(fileURLWithPath: outputPath))
print("Preview written to \(outputPath)")
