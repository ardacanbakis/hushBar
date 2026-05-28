import AppKit
import Combine

/// The geometric shape of the menu bar control.
enum BarShape: String, Codable, CaseIterable, Identifiable {
    case pill
    case roundedRect
    case rectangle
    case toggleSwitch
    case mic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill:         return "Pill"
        case .roundedRect:  return "Rounded Rectangle"
        case .rectangle:    return "Rectangle"
        case .toggleSwitch: return "Toggle Switch"
        case .mic:          return "Microphone"
        }
    }

    var symbolName: String {
        switch self {
        case .pill:         return "capsule.fill"
        case .roundedRect:  return "rectangle.fill"
        case .rectangle:    return "rectangle"
        case .toggleSwitch: return "switch.2"
        case .mic:          return "mic.fill"
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
        case .upper:   return "UPPER"
        case .lower:   return "lower"
        }
    }

    func apply(_ string: String) -> String {
        switch self {
        case .asTyped: return string
        case .upper:   return string.uppercased()
        case .lower:   return string.lowercased()
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
    var id: UUID
    var name: String
    var shape: BarShape
    var onText: String
    var offText: String
    var onColor: ColorComponents
    var offColor: ColorComponents
    var textCase: TextCase
    var onTextColor: ColorComponents
    var offTextColor: ColorComponents

    init(
        id: UUID = UUID(),
        name: String,
        shape: BarShape,
        onText: String,
        offText: String,
        onColor: ColorComponents,
        offColor: ColorComponents,
        textCase: TextCase = .asTyped,
        onTextColor: ColorComponents = ColorComponents(r: 1, g: 1, b: 1),
        offTextColor: ColorComponents = ColorComponents(r: 1, g: 1, b: 1)
    ) {
        self.id           = id
        self.name         = name
        self.shape        = shape
        self.onText       = onText
        self.offText      = offText
        self.onColor      = onColor
        self.offColor     = offColor
        self.textCase     = textCase
        self.onTextColor  = onTextColor
        self.offTextColor = offTextColor
    }

    // Forward-compatible decoder: missing keys (added in later versions) fall back to defaults.
    private enum CodingKeys: String, CodingKey {
        case id, name, shape, onText, offText, onColor, offColor, textCase, onTextColor, offTextColor
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,            forKey: .id)           ?? UUID()
        name         = try c.decode(String.self,                   forKey: .name)
        shape        = try c.decode(BarShape.self,                 forKey: .shape)
        onText       = try c.decode(String.self,                   forKey: .onText)
        offText      = try c.decode(String.self,                   forKey: .offText)
        onColor      = try c.decode(ColorComponents.self,          forKey: .onColor)
        offColor     = try c.decode(ColorComponents.self,          forKey: .offColor)
        textCase     = try c.decodeIfPresent(TextCase.self,        forKey: .textCase)     ?? .asTyped
        onTextColor  = try c.decodeIfPresent(ColorComponents.self, forKey: .onTextColor)  ?? ColorComponents(r: 1, g: 1, b: 1)
        offTextColor = try c.decodeIfPresent(ColorComponents.self, forKey: .offTextColor) ?? ColorComponents(r: 1, g: 1, b: 1)
    }

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
        guard let name = systemName,
              let sound = NSSound(named: NSSound.Name(name)),
              !sound.isPlaying else { return }
        sound.play()
    }
}

/// S / M / L / XL font size for the menu bar badge labels.
enum FontSize: String, CaseIterable, Identifiable, Codable {
    case small, medium, large, xlarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:   return "S"
        case .medium:  return "M"
        case .large:   return "L"
        case .xlarge:  return "XL"
        }
    }

    var points: CGFloat {
        switch self {
        case .small:   return 9
        case .medium:  return 11
        case .large:   return 13
        case .xlarge:  return 15
        }
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
    @Published var fontSize: FontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: Keys.fontSize) }
    }
    @Published var boldLabels: Bool {
        didSet { UserDefaults.standard.set(boldLabels, forKey: Keys.boldLabels) }
    }

    /// The preset currently shown in the menu bar. Falls back to the first.
    var selectedPreset: BarPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? presets[0]
    }

    private enum Keys {
        static let presets          = "presets.v1"
        static let selectedPresetID = "selectedPresetID"
        static let toggleSound      = "toggleSound"
        static let fontSize         = "fontSize"
        static let boldLabels       = "boldLabels"
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

            // --- Podcast / Creator ---
            BarPreset(name: "REC / Hush", shape: .pill,
                      onText: "REC", offText: "Hush",
                      onColor: ColorComponents(r: 0.82, g: 0.08, b: 0.10),
                      offColor: ColorComponents(r: 0.42, g: 0.44, b: 0.47),
                      textCase: .upper),
            BarPreset(name: "BROADCAST / Hushed", shape: .roundedRect,
                      onText: "BROADCAST", offText: "Hushed",
                      onColor: ColorComponents(r: 0.75, g: 0.18, b: 0.08),
                      offColor: ColorComponents(r: 0.40, g: 0.42, b: 0.48),
                      textCase: .upper),

            // --- Office / Meetings ---
            BarPreset(name: "In Meeting / Hush", shape: .pill,
                      onText: "In Meeting", offText: "Hush",
                      onColor: ColorComponents(r: 0.12, g: 0.35, b: 0.82),
                      offColor: ColorComponents(r: 0.38, g: 0.42, b: 0.50),
                      textCase: .asTyped),
            BarPreset(name: "ON CALL / Hushed", shape: .roundedRect,
                      onText: "ON CALL", offText: "Hushed",
                      onColor: ColorComponents(r: 0.08, g: 0.62, b: 0.68),
                      offColor: ColorComponents(r: 0.35, g: 0.38, b: 0.44),
                      textCase: .upper),

            // --- Streamer / Gamer ---
            BarPreset(name: "STREAMING / Shhh", shape: .toggleSwitch,
                      onText: "STREAMING", offText: "Shhh",
                      onColor: ColorComponents(r: 0.56, g: 0.25, b: 0.92),
                      offColor: ColorComponents(r: 0.28, g: 0.30, b: 0.36),
                      textCase: .asTyped),
            BarPreset(name: "GAMING / Hushed", shape: .roundedRect,
                      onText: "GAMING", offText: "Hushed",
                      onColor: ColorComponents(r: 0.12, g: 0.85, b: 0.42),
                      offColor: ColorComponents(r: 0.22, g: 0.24, b: 0.28),
                      textCase: .upper),

            // --- Minimal / Monochrome ---
            BarPreset(name: "ON / Hush", shape: .rectangle,
                      onText: "ON", offText: "Hush",
                      onColor: ColorComponents(r: 0.08, g: 0.08, b: 0.10),
                      offColor: ColorComponents(r: 0.45, g: 0.47, b: 0.50),
                      textCase: .upper),
            BarPreset(name: "Mic Icon", shape: .mic,
                      onText: "", offText: "",
                      onColor: ColorComponents(r: 0.28, g: 0.85, b: 0.48),
                      offColor: ColorComponents(r: 0.50, g: 0.52, b: 0.56),
                      textCase: .asTyped),
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
            toggleSound = (d.object(forKey: "playSoundOnToggle") as? Bool == false) ? .none : .pop
        }

        if let raw = d.string(forKey: Keys.fontSize),
           let size = FontSize(rawValue: raw) {
            fontSize = size
        } else {
            fontSize = .medium
        }

        if d.object(forKey: Keys.boldLabels) != nil {
            boldLabels = d.bool(forKey: Keys.boldLabels)
        } else {
            boldLabels = true
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
