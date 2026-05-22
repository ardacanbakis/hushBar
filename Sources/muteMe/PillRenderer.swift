import AppKit

/// Draws the menubar control in the selected style.
///
/// - `.toggleSwitch`: a rounded track with a sliding white knob and a label
///   (knob right + colored track when On, knob left + gray when Off).
/// - `.pill`: the original badge — a filled colored pill when On, a gray
///   outlined pill when Off.
enum PillRenderer {

    private static let height: CGFloat = 18

    static func image(
        style: PillStyle,
        on: Bool,
        onText: String,
        offText: String,
        onColor: NSColor,
        offColor: NSColor
    ) -> NSImage {
        let title = on ? onText : offText
        switch style {
        case .toggleSwitch:
            return toggleImage(on: on, title: title, onColor: onColor, offColor: offColor)
        case .pill:
            return pillImage(on: on, title: title, onColor: onColor, offColor: offColor)
        }
    }

    // MARK: - Toggle switch

    private static func toggleImage(on: Bool, title: String, onColor: NSColor, offColor: NSColor) -> NSImage {
        let pad: CGFloat = 6
        let gap: CGFloat = 5
        let knobInset: CGFloat = 2
        let knobDiameter = height - knobInset * 2

        let font = NSFont.systemFont(ofSize: 10, weight: .bold)
        let attributed = NSAttributedString(string: title, attributes: [
            .font: font, .foregroundColor: NSColor.white,
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

    // MARK: - Pill badge (original)

    private static func pillImage(on: Bool, title: String, onColor: NSColor, offColor: NSColor) -> NSImage {
        let horizontalPadding: CGFloat = 9
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let textColor: NSColor = on ? .white : offColor
        let attributed = NSAttributedString(string: title, attributes: [
            .font: font, .foregroundColor: textColor, .kern: 0.5,
        ])
        let textSize = attributed.size()

        let width = ceil(textSize.width) + horizontalPadding * 2
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
        let radius = rect.height / 2
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
}
