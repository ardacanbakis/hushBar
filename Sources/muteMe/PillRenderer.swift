import AppKit

/// Draws the menubar control as a toggle switch: a rounded pill track with a
/// white knob and an "On"/"Off" label. Knob sits right + colored track when the
/// mic is live (On); knob sits left + gray track when muted (Off).
enum PillRenderer {

    private static let height: CGFloat = 18
    private static let width: CGFloat = 52
    private static let knobInset: CGFloat = 2

    static func image(on: Bool, onColor: NSColor, offColor: NSColor) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        // Track
        let trackRect = NSRect(origin: .zero, size: size)
        let radius = height / 2
        let track = NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius)
        (on ? onColor : offColor).setFill()
        track.fill()

        // Knob
        let knobDiameter = height - knobInset * 2
        let knobX = on ? (width - knobDiameter - knobInset) : knobInset
        let knobRect = NSRect(x: knobX, y: knobInset, width: knobDiameter, height: knobDiameter)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knobRect).fill()

        // Label, placed in the open space opposite the knob.
        let title = on ? "On" : "Off"
        let font = NSFont.systemFont(ofSize: 10, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        let textSize = attributed.size()

        let labelCenterX: CGFloat = on
            ? (width - knobDiameter - knobInset) / 2
            : (knobInset + knobDiameter + width) / 2

        let textRect = NSRect(
            x: labelCenterX - textSize.width / 2,
            y: (height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height)
        attributed.draw(in: textRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
