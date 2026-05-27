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

/// Which sound plays when the mic is toggled.
enum ToggleSound: String, CaseIterable, Identifiable, Codable {
    case none, pop, tink, ping, glass, hero, funk, blow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:  return "None"
        case .pop:   return "Pop"
        case .tink:  return "Tink"
        case .ping:  return "Ping"
        case .glass: return "Glass"
        case .hero:  return "Hero"
        case .funk:  return "Funk"
        case .blow:  return "Blow"
        }
    }

    private var systemName: String? {
        switch self {
        case .none:  return nil
        case .pop:   return "Pop"
        case .tink:  return "Tink"
        case .ping:  return "Ping"
        case .glass: return "Glass"
        case .hero:  return "Hero"
        case .funk:  return "Funk"
        case .blow:  return "Blow"
        }
    }

    func play() {
        guard let name = systemName else { return }
        NSSound(named: NSSound.Name(name))?.play()
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
    @Published var toggleSound: ToggleSound {
        didSet { UserDefaults.standard.set(toggleSound.rawValue, forKey: Keys.toggleSound) }
    }

    /// The preset currently shown in the menu bar. Falls back to the first.
    var selectedPreset: BarPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? presets[0]
    }

    private enum Keys {
        static let presets = "presets.v1"
        static let selectedPresetID = "selectedPresetID"
        static let toggleSound = "toggleSound"
    }

    static let defaultRed  = ColorComponents(r: 0.62, g: 0.09, b: 0.09)
    static let defaultGray = ColorComponents(r: 0.42, g: 0.44, b: 0.47)

    static func defaultPresets() -> [BarPreset] {
        [
            // Classic radio booth — pill, signal red
            BarPreset(name: "ON AIR / Hush", shape: .pill,
                      onText: "ON AIR", offText: "Hush",
                      onColor: ColorComponents(r: 0.85, g: 0.12, b: 0.08),
                      offColor: ColorComponents(r: 0.45, g: 0.45, b: 0.45),
                      textCase: .asTyped),
            // Streaming / content creation — rounded rect, green
            BarPreset(name: "LIVE / Hushed", shape: .roundedRect,
                      onText: "LIVE", offText: "Hushed",
                      onColor: ColorComponents(r: 0.18, g: 0.72, b: 0.38),
                      offColor: ColorComponents(r: 0.38, g: 0.42, b: 0.50),
                      textCase: .asTyped),
            // Playful — toggle switch, electric orange
            BarPreset(name: "LIVE / Shhh", shape: .toggleSwitch,
                      onText: "LIVE", offText: "Shhh",
                      onColor: ColorComponents(r: 1.00, g: 0.45, b: 0.05),
                      offColor: ColorComponents(r: 0.38, g: 0.43, b: 0.52),
                      textCase: .asTyped),
            // Dramatic all-caps — rectangle, deep purple
            BarPreset(name: "ON AIR / Sssssh", shape: .rectangle,
                      onText: "ON AIR", offText: "Sssssh",
                      onColor: ColorComponents(r: 0.52, g: 0.18, b: 0.82),
                      offColor: ColorComponents(r: 0.32, g: 0.33, b: 0.36),
                      textCase: .upper),
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

        if let raw = d.string(forKey: Keys.toggleSound),
           let sound = ToggleSound(rawValue: raw) {
            toggleSound = sound
        } else {
            // migrate from old bool key; default new installs to .pop
            toggleSound = (d.object(forKey: "playSoundOnToggle") as? Bool == false) ? .none : .pop
        }
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
