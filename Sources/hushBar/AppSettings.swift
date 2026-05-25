import AppKit
import Combine

/// The visual style of the menubar control.
enum PillStyle: String, CaseIterable, Identifiable {
    case toggleSwitch
    case pill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggleSwitch: return "Toggle Switch"
        case .pill: return "Pill (ON AIR)"
        }
    }
}

/// User-tunable settings, persisted in `UserDefaults`.
/// Colors are stored as sRGB component arrays; other values as their raw types.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    static let defaultOnColor = NSColor(srgbRed: 0.62, green: 0.09, blue: 0.09, alpha: 1)   // darker red
    static let defaultOffColor = NSColor(srgbRed: 0.42, green: 0.44, blue: 0.47, alpha: 1)  // gray
    static let defaultOnText = "On"
    static let defaultOffText = "Off"

    @Published var buttonStyle: PillStyle {
        didSet { UserDefaults.standard.set(buttonStyle.rawValue, forKey: Keys.buttonStyle) }
    }
    @Published var onText: String {
        didSet { UserDefaults.standard.set(onText, forKey: Keys.onText) }
    }
    @Published var offText: String {
        didSet { UserDefaults.standard.set(offText, forKey: Keys.offText) }
    }
    @Published var onColor: NSColor {
        didSet { persist(onColor, forKey: Keys.onColor) }
    }
    @Published var offColor: NSColor {
        didSet { persist(offColor, forKey: Keys.offColor) }
    }

    private enum Keys {
        static let buttonStyle = "buttonStyle"
        static let onText = "onText"
        static let offText = "offText"
        static let onColor = "onColor"
        static let offColor = "offColor"
    }

    private init() {
        let d = UserDefaults.standard
        buttonStyle = PillStyle(rawValue: d.string(forKey: Keys.buttonStyle) ?? "") ?? .toggleSwitch
        onText = d.string(forKey: Keys.onText) ?? AppSettings.defaultOnText
        offText = d.string(forKey: Keys.offText) ?? AppSettings.defaultOffText
        onColor = AppSettings.load(Keys.onColor) ?? AppSettings.defaultOnColor
        offColor = AppSettings.load(Keys.offColor) ?? AppSettings.defaultOffColor
    }

    func resetStyle() {
        buttonStyle = .toggleSwitch
        onText = AppSettings.defaultOnText
        offText = AppSettings.defaultOffText
        onColor = AppSettings.defaultOnColor
        offColor = AppSettings.defaultOffColor
    }

    private func persist(_ color: NSColor, forKey key: String) {
        guard let c = color.usingColorSpace(.sRGB) else { return }
        let components = [
            Double(c.redComponent), Double(c.greenComponent),
            Double(c.blueComponent), Double(c.alphaComponent),
        ]
        UserDefaults.standard.set(components, forKey: key)
    }

    private static func load(_ key: String) -> NSColor? {
        guard let c = UserDefaults.standard.array(forKey: key) as? [Double], c.count == 4 else {
            return nil
        }
        return NSColor(srgbRed: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: CGFloat(c[3]))
    }
}
