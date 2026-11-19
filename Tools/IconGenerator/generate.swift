import Cocoa
import CoreGraphics

func createLoomaWordIcon() -> NSImage {
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
    let shadowColor = NSColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 0.40).cgColor
    ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 36, color: shadowColor)

    let margin: CGFloat = 104.0
    let bodySize: CGFloat = 816.0
    let cornerRadius: CGFloat = 186.0
    let squircleRect = CGRect(x: margin, y: margin, width: bodySize, height: bodySize)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // ==========================================
    // 2. Base Squircle Surface with Clipping
    // ==========================================
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Background Gradient: Deep Oceanic Twilight
    let bgColors = [
        NSColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1.0).cgColor
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
        NSColor(red: 0.18, green: 0.28, blue: 0.65, alpha: 0.25).cgColor,
        NSColor(red: 0.06, green: 0.08, blue: 0.20, alpha: 0.0).cgColor
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: 512, y: 512),
        startRadius: 40,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 380,
        options: []
    )

    // Inner Border highlight (macOS subtle frosted glass rim)
    ctx.saveGState()
    ctx.setLineWidth(2.0)
    let rimColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.24).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.03).cgColor
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
    // 3. Central Emblem: "The Looma Weave & Spark"
    // ==========================================
    // Two interlocking rounded geometric ribbons:
    // Left ribbon (L-wing): Starts top-left, curves down, sweeps across base, curving up into center.
    // Right ribbon (W-wing): Interlocks with left ribbon, forming a harmonious infinity / wave geometry.
    // In the core: A luminous translation spark (4-pointed star).

    let cx: CGFloat = 512
    let cy: CGFloat = 512

    // Dimensions
    let podWidth: CGFloat = 360
    let podHeight: CGFloat = 200
    let podCorner: CGFloat = 100 // Full capsule pill

    // Left Pod (Source Language Pod)
    // Angled slightly by -18 degrees, centered around (cx - 70, cy + 30)
    ctx.saveGState()
    ctx.translateBy(x: cx - 65, y: cy + 40)
    ctx.rotate(by: -22.0 * .pi / 180.0)

    let leftPodRect = CGRect(x: -podWidth/2, y: -podHeight/2, width: podWidth, height: podHeight)
    let leftPodPath = CGPath(roundedRect: leftPodRect, cornerWidth: podCorner, cornerHeight: podCorner, transform: nil)

    // Left Pod Gradient: Electric Cyan (#00F2FE) to Deep Azure (#4FACFE)
    let leftColors = [
        NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.92).cgColor,
        NSColor(red: 0.15, green: 0.45, blue: 0.98, alpha: 0.90).cgColor
    ] as CFArray
    let leftGrad = CGGradient(colorsSpace: colorSpace, colors: leftColors, locations: [0.0, 1.0])!

    // Soft drop shadow for Left Pod
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor(red: 0, green: 0.3, blue: 0.8, alpha: 0.45).cgColor)
    ctx.addPath(leftPodPath)
    ctx.fillPath()

    // Inner gradient fill
    ctx.addPath(leftPodPath)
    ctx.clip()
    ctx.drawLinearGradient(
        leftGrad,
        start: CGPoint(x: -podWidth/2, y: podHeight/2),
        end: CGPoint(x: podWidth/2, y: -podHeight/2),
        options: []
    )
    ctx.restoreGState()

    // Right Pod (Target Language Pod)
    // Angled slightly by +22 degrees, centered around (cx + 65, cy - 40)
    ctx.saveGState()
    ctx.translateBy(x: cx + 65, y: cy - 40)
    ctx.rotate(by: -22.0 * .pi / 180.0) // parallel sleek slant

    let rightPodRect = CGRect(x: -podWidth/2, y: -podHeight/2, width: podWidth, height: podHeight)
    let rightPodPath = CGPath(roundedRect: rightPodRect, cornerWidth: podCorner, cornerHeight: podCorner, transform: nil)

    // Right Pod Gradient: Vivid Sunset Rose (#FF2A6D) to Neon Violet/Purple (#9B51E0)
    let rightColors = [
        NSColor(red: 1.0, green: 0.22, blue: 0.55, alpha: 0.88).cgColor,
        NSColor(red: 0.58, green: 0.20, blue: 0.95, alpha: 0.88).cgColor
    ] as CFArray
    let rightGrad = CGGradient(colorsSpace: colorSpace, colors: rightColors, locations: [0.0, 1.0])!

    // Blend mode to create stunning optical refraction where the two pods intersect
    ctx.setBlendMode(.screen)
    ctx.addPath(rightPodPath)
    ctx.clip()
    ctx.drawLinearGradient(
        rightGrad,
        start: CGPoint(x: -podWidth/2, y: -podHeight/2),
        end: CGPoint(x: podWidth/2, y: podHeight/2),
        options: []
    )
    ctx.restoreGState()

    // Central Luminous Spark (Looma Star)
    // A brilliant 4-pointed diamond star at the exact intersection (cx, cy)
    ctx.saveGState()
    ctx.setBlendMode(.normal)

    // Star Outer Glow
    let starGlowColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9).cgColor,
        NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.4).cgColor,
        NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let starGlowGrad = CGGradient(colorsSpace: colorSpace, colors: starGlowColors, locations: [0.0, 0.4, 1.0])!
    ctx.drawRadialGradient(
        starGlowGrad,
        startCenter: CGPoint(x: cx, y: cy),
        startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy),
        endRadius: 65,
        options: []
    )

    // 4-pointed Star Geometry
    let starPath = CGMutablePath()
    let starRadiusLarge: CGFloat = 38.0
    let starRadiusSmall: CGFloat = 9.0

    for i in 0..<8 {
        let angle = CGFloat(i) * (.pi / 4.0) - (.pi / 2.0)
        let r = (i % 2 == 0) ? starRadiusLarge : starRadiusSmall
        let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
        if i == 0 {
            starPath.move(to: pt)
        } else {
            starPath.addLine(to: pt)
        }
    }
    starPath.closeSubpath()

    ctx.addPath(starPath)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()

    ctx.restoreGState()

    // Restore Squircle Clip
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

let icon = createLoomaWordIcon()
guard let tiffData = icon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = "dist/preview_icon.png"
try? pngData.write(to: URL(fileURLWithPath: outputPath))
print("Preview written to \(outputPath)")
