import AppKit

/// Draws the menubar pill image for each state, matching the reference design:
/// a red filled "ON AIR" pill when the mic is live, and a gray outlined
/// "OFF AIR" pill when muted.
enum PillRenderer {

    private static let height: CGFloat = 18
    private static let horizontalPadding: CGFloat = 9
    private static let fontSize: CGFloat = 11

    static func image(muted: Bool) -> NSImage {
        let title = muted ? "OFF AIR" : "ON AIR"

        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let textColor: NSColor = muted ? .secondaryLabelColor : .white

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .kern: 0.5,
        ]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        let textSize = attributed.size()

        let width = ceil(textSize.width) + horizontalPadding * 2
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
        let radius = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        if muted {
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        } else {
            NSColor.systemRed.setFill()
            path.fill()
        }

        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height)
        attributed.draw(in: textRect)

        image.unlockFocus()

        // Colored artwork, so it must not be tinted as a template.
        image.isTemplate = false
        return image
    }
}
