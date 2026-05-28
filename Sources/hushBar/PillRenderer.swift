import AppKit

/// Draws the menu bar control for a given preset and on/off state.
enum PillRenderer {

    private static let height: CGFloat = 18

    static func image(preset: BarPreset, on: Bool) -> NSImage {
        let title        = preset.text(on: on)
        let onColor      = preset.onColor.nsColor
        let offColor     = preset.offColor.nsColor
        let textColor    = on ? preset.onTextColor.nsColor : preset.offTextColor.nsColor
        let fontSize     = AppSettings.shared.fontSize.points
        let fontWeight   = AppSettings.shared.boldLabels ? NSFont.Weight.bold : .regular

        switch preset.shape {
        case .toggleSwitch:
            return toggleImage(on: on, title: title, onColor: onColor, offColor: offColor,
                               textColor: textColor, fontSize: fontSize, fontWeight: fontWeight)
        case .pill:
            return badgeImage(on: on, title: title, onColor: onColor, offColor: offColor,
                              textColor: textColor, radius: height / 2, fontSize: fontSize, fontWeight: fontWeight)
        case .roundedRect:
            return badgeImage(on: on, title: title, onColor: onColor, offColor: offColor,
                              textColor: textColor, radius: 5, fontSize: fontSize, fontWeight: fontWeight)
        case .rectangle:
            return badgeImage(on: on, title: title, onColor: onColor, offColor: offColor,
                              textColor: textColor, radius: 0, fontSize: fontSize, fontWeight: fontWeight)
        case .mic:
            return micImage(on: on, onColor: onColor, offColor: offColor)
        }
    }

    // MARK: - Toggle switch

    private static func toggleImage(
        on: Bool, title: String, onColor: NSColor, offColor: NSColor,
        textColor: NSColor, fontSize: CGFloat, fontWeight: NSFont.Weight
    ) -> NSImage {
        let pad: CGFloat = 6
        let gap: CGFloat = 5
        let knobInset: CGFloat = 2
        let knobDiameter = height - knobInset * 2

        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let attributed = NSAttributedString(string: title, attributes: [
            .font: font, .foregroundColor: textColor,
        ])
        let textSize = attributed.size()

        let width = pad + ceil(textSize.width) + gap + knobDiameter + pad
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        let radius = height / 2
        let track = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius)
        (on ? onColor : offColor).setFill()
        track.fill()

        let knobX: CGFloat
        let textX: CGFloat
        if on {
            textX = pad
            knobX = width - pad - knobDiameter
        } else {
            knobX = pad
            textX = pad + knobDiameter + gap
        }

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: knobX, y: knobInset, width: knobDiameter, height: knobDiameter)).fill()

        attributed.draw(in: NSRect(
            x: textX, y: (height - textSize.height) / 2,
            width: textSize.width, height: textSize.height))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Text badge (pill / rounded / rectangle)

    private static func badgeImage(
        on: Bool, title: String, onColor: NSColor, offColor: NSColor,
        textColor: NSColor, radius: CGFloat, fontSize: CGFloat, fontWeight: NSFont.Weight
    ) -> NSImage {
        let horizontalPadding: CGFloat = 9
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let attributed = NSAttributedString(string: title, attributes: [
            .font: font, .foregroundColor: textColor, .kern: 0.5,
        ])
        let textSize = attributed.size()

        let width = ceil(textSize.width) + horizontalPadding * 2
        let size = NSSize(width: max(width, height), height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        if on {
            onColor.setFill()
            path.fill()
        } else {
            offColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        attributed.draw(in: NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width, height: textSize.height))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Mic icon

    private static func micImage(on: Bool, onColor: NSColor, offColor: NSColor) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let color = on ? onColor : offColor

        // Capsule mic body
        let bw: CGFloat = 7
        let bh: CGFloat = 10
        let bx = (size.width - bw) / 2
        let by: CGFloat = 7
        let bodyPath = NSBezierPath(
            roundedRect: NSRect(x: bx, y: by, width: bw, height: bh),
            xRadius: bw / 2, yRadius: bw / 2)
        color.setFill()
        bodyPath.fill()

        // U-shaped collar wrapping the bottom of the mic body
        let arcCenter = NSPoint(x: size.width / 2, y: by)
        let collar = NSBezierPath()
        collar.appendArc(withCenter: arcCenter, radius: 5.5,
                         startAngle: 0, endAngle: 180, clockwise: true)
        color.setStroke()
        collar.lineWidth = 1.5
        collar.lineCapStyle = .butt
        collar.stroke()

        // Vertical stem
        let stemPath = NSBezierPath()
        stemPath.move(to: NSPoint(x: size.width / 2, y: by - 5.5))
        stemPath.line(to: NSPoint(x: size.width / 2, y: 1.5))
        stemPath.lineWidth = 1.5
        stemPath.lineCapStyle = .butt
        stemPath.stroke()

        // Horizontal base
        let basePath = NSBezierPath()
        basePath.move(to: NSPoint(x: size.width / 2 - 3.5, y: 1.5))
        basePath.line(to: NSPoint(x: size.width / 2 + 3.5, y: 1.5))
        basePath.lineWidth = 1.5
        basePath.lineCapStyle = .round
        basePath.stroke()

        // Red diagonal slash when muted
        if !on {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 3.5, y: 1.5))
            slash.line(to: NSPoint(x: 16.5, y: 16.5))
            NSColor(red: 0.92, green: 0.12, blue: 0.12, alpha: 1).setStroke()
            slash.lineWidth = 2
            slash.lineCapStyle = .round
            slash.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
