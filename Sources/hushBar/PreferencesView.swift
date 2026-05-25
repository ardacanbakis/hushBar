import SwiftUI
import KeyboardShortcuts

enum PrefsTab: Hashable {
    case general, style, about
}

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings

    @State private var selectedTab: PrefsTab = .general
    /// Which preset the Style tab is editing. Defaults to the selected one.
    @State private var editingPresetID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            TopHalf {
                GeneralSettingsView(
                    mic: mic, settings: settings,
                    onEditPreset: { id in
                        editingPresetID = id
                        selectedTab = .style
                    })
            }
            .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            .tag(PrefsTab.general)

            TopHalf {
                StyleSettingsView(settings: settings, editingPresetID: editingBinding)
            }
            .tabItem { Label("Style", systemImage: "paintpalette") }
            .tag(PrefsTab.style)

            TopHalf { AboutView() }
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(PrefsTab.about)
        }
        .frame(width: 480, height: 720)
    }

    /// Bridges the optional editing id to a non-optional binding, defaulting to
    /// the currently selected preset when nothing has been chosen yet.
    private var editingBinding: Binding<UUID> {
        Binding(
            get: { editingPresetID ?? settings.selectedPresetID },
            set: { editingPresetID = $0 })
    }
}

/// Centers its content within the top half of the available area.
private struct TopHalf<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer(minLength: 0)
        }
    }
}

/// A small icon + title header shown at the top of each page.
private struct PageHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings
    let onEditPreset: (UUID) -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(icon: "slider.horizontal.3", title: "General",
                       subtitle: "Pick a look, set your shortcut, and tune behavior.")

            GroupBox("Menu Bar Style") {
                PresetCarousel(settings: settings, onEdit: onEditPreset)
                    .padding(6)
            }

            GroupBox("Global Shortcut") {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }

            GroupBox {
                VStack(spacing: 8) {
                    Toggle("Launch HushBar at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in LaunchAtLogin.isEnabled = newValue }
                    Toggle("Play a sound when toggling", isOn: $settings.playSoundOnToggle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox {
                HStack {
                    Text("Microphone")
                    Spacer()
                    Text(mic.isMuted ? "Muted" : "Live")
                        .foregroundColor(mic.isMuted ? .secondary : Color(nsColor: settings.selectedPreset.onColor.nsColor))
                        .fontWeight(.semibold)
                }
                .padding(6)
            }
        }
        .frame(width: 380)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

/// Horizontal scroller of saved presets with Use / Edit actions.
private struct PresetCarousel: View {
    @ObservedObject var settings: AppSettings
    let onEdit: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(settings.presets) { preset in
                    PresetCard(
                        preset: preset,
                        isSelected: preset.id == settings.selectedPresetID,
                        onUse: { settings.selectedPresetID = preset.id },
                        onEdit: { onEdit(preset.id) })
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }
}

private struct PresetCard: View {
    let preset: BarPreset
    let isSelected: Bool
    let onUse: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: PillRenderer.image(preset: preset, on: true))
            Image(nsImage: PillRenderer.image(preset: preset, on: false))
            Text(preset.name)
                .font(.caption).fontWeight(.medium)
                .lineLimit(1)
            HStack(spacing: 6) {
                Button("Use", action: onUse)
                    .controlSize(.small)
                    .disabled(isSelected)
                Button("Edit", action: onEdit)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .frame(width: 132)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1))
    }
}

// MARK: - Style

private struct StyleSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var editingPresetID: UUID

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(icon: "paintpalette", title: "Style",
                       subtitle: "Design the menu bar control and save it as a preset.")

            Picker("Editing preset", selection: $editingPresetID) {
                ForEach(settings.presets) { Text($0.name).tag($0.id) }
            }
            .frame(width: 360)

            if let binding = presetBinding {
                PresetEditor(settings: settings, preset: binding,
                             editingPresetID: $editingPresetID)
            } else {
                Text("No preset selected.").foregroundColor(.secondary)
            }
        }
        .frame(width: 380)
    }

    /// A binding to the element of `settings.presets` currently being edited.
    private var presetBinding: Binding<BarPreset>? {
        let id = editingPresetID
        guard settings.presets.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { settings.presets.first(where: { $0.id == id }) ?? settings.presets[0] },
            set: { settings.updatePreset($0) })
    }
}

private struct PresetEditor: View {
    @ObservedObject var settings: AppSettings
    @Binding var preset: BarPreset
    @Binding var editingPresetID: UUID

    var body: some View {
        VStack(spacing: 14) {
            GroupBox("Preview") {
                HStack(spacing: 16) {
                    Image(nsImage: PillRenderer.image(preset: preset, on: true))
                    Image(nsImage: PillRenderer.image(preset: preset, on: false))
                }
                .padding(8)
                .frame(maxWidth: .infinity)
            }

            GroupBox("Preset") {
                VStack(spacing: 8) {
                    TextField("Preset name", text: $preset.name)
                    Picker("Shape", selection: $preset.shape) {
                        ForEach(BarShape.allCases) { shape in
                            Label(shape.displayName, systemImage: shape.symbolName).tag(shape)
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Labels") {
                VStack(spacing: 8) {
                    TextField("On label", text: $preset.onText)
                    TextField("Off label", text: $preset.offText)
                    Picker("Capitalization", selection: $preset.textCase) {
                        ForEach(TextCase.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(6)
            }

            GroupBox("Colors") {
                VStack(spacing: 8) {
                    ColorPicker("On color", selection: Binding(
                        get: { Color(nsColor: preset.onColor.nsColor) },
                        set: { preset.onColor = ColorComponents(NSColor($0)) }))
                    ColorPicker("Off color", selection: Binding(
                        get: { Color(nsColor: preset.offColor.nsColor) },
                        set: { preset.offColor = ColorComponents(NSColor($0)) }))
                }
                .padding(6)
            }

            HStack {
                Button("Use This Preset") { settings.selectedPresetID = preset.id }
                    .disabled(settings.selectedPresetID == preset.id)
                Spacer()
                Button("Duplicate") {
                    if let newID = settings.duplicatePreset(preset.id) { editingPresetID = newID }
                }
                Button("Delete", role: .destructive) {
                    let id = preset.id
                    settings.deletePreset(id)
                    editingPresetID = settings.selectedPresetID
                }
                .disabled(settings.presets.count <= 1)
            }
            .controlSize(.small)

            Button("Reset all presets to defaults") {
                settings.resetToDefaults()
                editingPresetID = settings.selectedPresetID
            }
            .font(.caption)
        }
    }
}

// MARK: - About

private struct SocialLink: Identifiable {
    let brand: Brand
    let label: String
    let url: URL
    var id: String { label }
}

private struct AboutView: View {
    private let links: [SocialLink] = [
        .init(brand: .website, label: "Website", url: URL(string: "https://ardacanbakis.com")!),
        .init(brand: .github, label: "GitHub", url: URL(string: "https://github.com/ardacanbakis")!),
        .init(brand: .instagram, label: "Instagram", url: URL(string: "https://www.instagram.com/arda.canbakiss/")!),
        .init(brand: .youtube, label: "YouTube", url: URL(string: "https://www.youtube.com/@arda.canbakis")!),
        .init(brand: .spotify, label: "Spotify", url: URL(string: "https://open.spotify.com/user/11146430303")!),
        .init(brand: .linkedin, label: "LinkedIn", url: URL(string: "https://linkedin.com/in/ardacanbakis")!),
    ]

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(v)"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)

            VStack(spacing: 2) {
                Text("HushBar").font(.title2).fontWeight(.bold)
                Text("Mute your microphone from the menu bar.")
                    .font(.callout).foregroundColor(.secondary)
                Text(version).font(.caption).foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                ForEach(links) { link in
                    Link(destination: link.url) { BrandIcon(brand: link.brand, size: 24) }
                        .buttonStyle(.plain)
                        .help(link.label)
                }
            }
            .padding(.top, 4)

            BuyMeACoffeeButton()

            footer
        }
        .padding(28)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Text("Created with")
            Image(systemName: "heart.fill").foregroundColor(.red)
            Text("by")
            DancingName(text: "Arda Canbakis", url: URL(string: "https://ardacanbakis.com")!)
            Text("© 2026")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

/// A friendly call-to-action that opens the creator's Buy Me a Coffee page.
private struct BuyMeACoffeeButton: View {
    @Environment(\.openURL) private var openURL
    private let url = URL(string: "https://buymeacoffee.com/ardacanbakis")!

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                Text("Buy me a coffee")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color(red: 1.0, green: 0.86, blue: 0.0)))
            .foregroundColor(.black)
        }
        .buttonStyle(.plain)
        .help("Support HushBar — opens buymeacoffee.com")
    }
}

/// A playful, color-shifting, gently bobbing rendition of a name that opens a URL.
private struct DancingName: View {
    let text: String
    let url: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, ch in
                    Text(String(ch))
                        .offset(y: sin(t * 3 + Double(index) * 0.45) * 2.2)
                }
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                    startPoint: .leading, endPoint: .trailing))
            .hueRotation(.degrees(t * 60))
        }
        .onTapGesture { openURL(url) }
        .help("Open ardacanbakis.com")
    }
}
