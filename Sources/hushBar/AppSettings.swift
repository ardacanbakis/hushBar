import AppKit
import Combine

/// The geometric shape of the menu bar control.
enum BarShape: String, Codable, CaseIterable, Identifiable {
    case pill
    case roundedRect
    case rectangle
    case toggleSwitch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Pill"
        case .roundedRect: return "Rounded Rectangle"
        case .rectangle: return "Rectangle"
        case .toggleSwitch: return "Toggle Switch"
        }
    }

    var symbolName: String {
        switch self {
        case .pill: return "capsule.fill"
        case .roundedRect: return "rectangle.fill"
        case .rectangle: return "rectangle"
        case .toggleSwitch: return "switch.2"
        }
    }
}

/// How preset label text is cased when rendered.
enum TextCase: String, Codable, CaseIterable, Identifiable {
    case asTyped
    case upper
    case lower

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asTyped: return "As Typed"
        case .upper: return "UPPER"
        case .lower: return "lower"
        }
    }

    func apply(_ string: String) -> String {
        switch self {
        case .asTyped: return string
        case .upper: return string.uppercased()
        case .lower: return string.lowercased()
        }
    }
}

/// A Codable sRGB color, since `NSColor` isn't directly Codable.
struct ColorComponents: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        r = Double(c.redComponent)
        g = Double(c.greenComponent)
        b = Double(c.blueComponent)
        a = Double(c.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

/// A named, fully-editable look for the menu bar control.
struct BarPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var shape: BarShape
    var onText: String
    var offText: String
    var onColor: ColorComponents
    var offColor: ColorComponents
    var textCase: TextCase = .asTyped

    /// The label for a given state, with the case rule applied.
    func text(on: Bool) -> String {
        textCase.apply(on ? onText : offText)
    }
}

/// User-tunable settings, persisted in `UserDefaults`.
/// Presets are stored as JSON; scalar prefs as their raw types.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    @Published var presets: [BarPreset] {
        didSet { persistPresets() }
    }
    @Published var selectedPresetID: UUID {
        didSet { UserDefaults.standard.set(selectedPresetID.uuidString, forKey: Keys.selectedPresetID) }
    }
    @Published var playSoundOnToggle: Bool {
        didSet { UserDefaults.standard.set(playSoundOnToggle, forKey: Keys.playSoundOnToggle) }
    }

    /// The preset currently shown in the menu bar. Falls back to the first.
    var selectedPreset: BarPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? presets[0]
    }

    private enum Keys {
        static let presets = "presets.v1"
        static let selectedPresetID = "selectedPresetID"
        static let playSoundOnToggle = "playSoundOnToggle"
    }

    static let defaultRed = ColorComponents(r: 0.62, g: 0.09, b: 0.09)
    static let defaultGray = ColorComponents(r: 0.42, g: 0.44, b: 0.47)

    static func defaultPresets() -> [BarPreset] {
        [
            BarPreset(name: "On Air", shape: .pill,
                      onText: "ON AIR", offText: "OFF AIR",
                      onColor: defaultRed, offColor: defaultGray),
            BarPreset(name: "Live / Hush", shape: .roundedRect,
                      onText: "LIVE", offText: "HUSH",
                      onColor: defaultRed, offColor: defaultGray),
            BarPreset(name: "Live / Muted", shape: .pill,
                      onText: "LIVE", offText: "MUTED",
                      onColor: defaultRed, offColor: defaultGray),
        ]
    }

    private init() {
        let d = UserDefaults.standard

        let loaded: [BarPreset]
        if let data = d.data(forKey: Keys.presets),
           let decoded = try? JSONDecoder().decode([BarPreset].self, from: data),
           !decoded.isEmpty {
            loaded = decoded
        } else {
            loaded = AppSettings.defaultPresets()
        }
        presets = loaded

        if let raw = d.string(forKey: Keys.selectedPresetID),
           let uuid = UUID(uuidString: raw),
           loaded.contains(where: { $0.id == uuid }) {
            selectedPresetID = uuid
        } else {
            selectedPresetID = loaded[0].id
        }

        playSoundOnToggle = d.bool(forKey: Keys.playSoundOnToggle)
    }

    // MARK: - Preset mutation

    func updatePreset(_ preset: BarPreset) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = preset
    }

    /// Duplicates a preset, appends it, and returns the new id.
    @discardableResult
    func duplicatePreset(_ id: UUID) -> UUID? {
        guard let original = presets.first(where: { $0.id == id }) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.name = "\(original.name) Copy"
        presets.append(copy)
        return copy.id
    }

    func deletePreset(_ id: UUID) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
        if selectedPresetID == id { selectedPresetID = presets[0].id }
    }

    func resetToDefaults() {
        presets = AppSettings.defaultPresets()
        selectedPresetID = presets[0].id
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: Keys.presets)
    }
}
