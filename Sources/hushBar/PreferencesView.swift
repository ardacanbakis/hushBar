import SwiftUI
import KeyboardShortcuts

enum PrefsTab: Hashable { case general, style, about }

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings

    @State private var selectedTab: PrefsTab = .general
    @State private var editingPresetID: UUID?
    @State private var activeColorTarget: ColorTarget?

    private var showingColorPanel: Bool {
        selectedTab == .style && activeColorTarget != nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                mic: mic, settings: settings,
                onEditPreset: { id in
                    editingPresetID = id
                    selectedTab = .style
                }
            )
            .tabItem { Label("General", systemImage: "gearshape") }
            .tag(PrefsTab.general)

            StyleSettingsView(
                settings: settings,
                editingPresetID: editingBinding,
                activeColorTarget: $activeColorTarget
            )
            .tabItem { Label("Style", systemImage: "paintpalette") }
            .tag(PrefsTab.style)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(PrefsTab.about)
        }
        .frame(width: showingColorPanel ? 856 : 640, height: 600)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showingColorPanel)
        .onChange(of: selectedTab) { _ in
            withAnimation { activeColorTarget = nil }
        }
    }

    private var editingBinding: Binding<UUID> {
        Binding(
            get: { editingPresetID ?? settings.selectedPresetID },
            set: { editingPresetID = $0 }
        )
    }
}

// MARK: - Page header

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
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(icon: "gearshape", title: "General",
                           subtitle: "Set your shortcut, pick a look, and tune behavior.")

                GroupBox("Current Style") {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(nsImage: PillRenderer.image(preset: settings.selectedPreset, on: true))
                            Image(nsImage: PillRenderer.image(preset: settings.selectedPreset, on: false))
                        }
                        Text(settings.selectedPreset.name)
                            .font(.callout).fontWeight(.medium)
                            .lineLimit(1)
                        Spacer()
                        Button("Edit Styles…") {
                            onEditPreset(settings.selectedPresetID)
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                }

                GroupBox("Global Shortcut") {
                    KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }

                GroupBox {
                    VStack(spacing: 10) {
                        Toggle("Launch HushBar at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in LaunchAtLogin.isEnabled = newValue }

                        HStack {
                            Text("Toggle sound")
                            Spacer()
                            Picker("", selection: $settings.toggleSound) {
                                ForEach(ToggleSound.allCases) { sound in
                                    Text(sound.displayName).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            .pickerStyle(.menu)

                            Button {
                                settings.toggleSound.play()
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .disabled(settings.toggleSound == .none)
                            .opacity(settings.toggleSound == .none ? 0.3 : 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }

                GroupBox {
                    HStack {
                        Text("Microphone")
                        Spacer()
                        Text(mic.isMuted ? "Muted" : "Live")
                            .foregroundColor(mic.isMuted
                                ? .secondary
                                : Color(nsColor: settings.selectedPreset.onColor.nsColor))
                            .fontWeight(.semibold)
                    }
                    .padding(6)
                }
            }
            .padding(20)
            .frame(width: 400)
            .frame(maxWidth: .infinity)
        }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: - Style (master-detail)

private struct StyleSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var editingPresetID: UUID
    @Binding var activeColorTarget: ColorTarget?

    var body: some View {
        HStack(spacing: 0) {
            PresetListSidebar(settings: settings, editingPresetID: $editingPresetID)
            Divider()
            if let binding = presetBinding {
                PresetEditorView(
                    settings: settings,
                    preset: binding,
                    editingPresetID: $editingPresetID,
                    activeColorTarget: $activeColorTarget
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No preset selected.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let target = activeColorTarget, let binding = presetBinding {
                let colorBinding = Binding<ColorComponents>(
                    get: {
                        target == .on
                            ? binding.wrappedValue.onColor
                            : binding.wrappedValue.offColor
                    },
                    set: { newVal in
                        var p = binding.wrappedValue
                        if target == .on { p.onColor = newVal } else { p.offColor = newVal }
                        binding.wrappedValue = p
                    }
                )
                Divider()
                ColorEditorPanel(
                    title: target == .on ? "On color" : "Off color",
                    color: colorBinding,
                    onDone: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            activeColorTarget = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var presetBinding: Binding<BarPreset>? {
        let id = editingPresetID
        guard settings.presets.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { settings.presets.first(where: { $0.id == id }) ?? settings.presets[0] },
            set: { settings.updatePreset($0) }
        )
    }
}

// MARK: - Preset list sidebar

private struct PresetListSidebar: View {
    @ObservedObject var settings: AppSettings
    @Binding var editingPresetID: UUID

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(settings.presets) { preset in
                        presetRow(preset)
                    }
                }
                .padding(6)
            }
            Divider()
            HStack(spacing: 0) {
                Button {
                    if let newID = settings.duplicatePreset(editingPresetID) {
                        editingPresetID = newID
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                Divider().frame(height: 24)
                Button {
                    guard settings.presets.count > 1 else { return }
                    settings.deletePreset(editingPresetID)
                    editingPresetID = settings.selectedPresetID
                } label: {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .disabled(settings.presets.count <= 1)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 160)
    }

    @ViewBuilder
    private func presetRow(_ preset: BarPreset) -> some View {
        let isEditing = preset.id == editingPresetID
        let isActive  = preset.id == settings.selectedPresetID
        Button { editingPresetID = preset.id } label: {
            HStack(spacing: 8) {
                Image(nsImage: PillRenderer.image(preset: preset, on: true))
                Text(preset.name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEditing ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isEditing ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        // double-click activates the preset in the menu bar
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                editingPresetID = preset.id
                settings.selectedPresetID = preset.id
            }
        )
    }
}

// MARK: - Preset editor

private struct PresetEditorView: View {
    @ObservedObject var settings: AppSettings
    @Binding var preset: BarPreset
    @Binding var editingPresetID: UUID
    @Binding var activeColorTarget: ColorTarget?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // prominent live preview on a simulated menu-bar strip
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)))
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Image(nsImage: PillRenderer.image(preset: preset, on: true))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 27)
                            Text("On").font(.caption2).foregroundColor(.gray)
                        }
                        VStack(spacing: 4) {
                            Image(nsImage: PillRenderer.image(preset: preset, on: false))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 27)
                            Text("Off").font(.caption2).foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                }
                .frame(height: 84)

                GroupBox("Preset") {
                    VStack(spacing: 8) {
                        TextField("Name", text: $preset.name)
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
                        Picker("Case", selection: $preset.textCase) {
                            ForEach(TextCase.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(6)
                }

                GroupBox("Colors") {
                    VStack(spacing: 8) {
                        colorSwatchRow("On color",  components: preset.onColor,  target: .on)
                        colorSwatchRow("Off color", components: preset.offColor, target: .off)
                    }
                    .padding(6)
                }

                HStack {
                    Button("Use This Preset") { settings.selectedPresetID = preset.id }
                        .disabled(settings.selectedPresetID == preset.id)
                    Spacer()
                    Button("Duplicate") {
                        if let newID = settings.duplicatePreset(preset.id) {
                            editingPresetID = newID
                        }
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
            .padding(16)
        }
    }

    @ViewBuilder
    private func colorSwatchRow(
        _ label: String, components: ColorComponents, target: ColorTarget
    ) -> some View {
        let isActive = activeColorTarget == target
        Button {
            withAnimation(.spring(response: 0.3)) {
                activeColorTarget = isActive ? nil : target
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: components.nsColor))
                    .frame(width: 44, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                isActive ? Color.accentColor : Color.primary.opacity(0.2),
                                lineWidth: isActive ? 2 : 1
                            )
                    )
            }
        }
        .buttonStyle(.plain)
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
        .init(brand: .website,   label: "Website",   url: URL(string: "https://ardacanbakis.com")!),
        .init(brand: .github,    label: "GitHub",    url: URL(string: "https://github.com/ardacanbakis")!),
        .init(brand: .instagram, label: "Instagram", url: URL(string: "https://www.instagram.com/arda.canbakiss/")!),
        .init(brand: .youtube,   label: "YouTube",   url: URL(string: "https://www.youtube.com/@arda.canbakis")!),
        .init(brand: .spotify,   label: "Spotify",   url: URL(string: "https://open.spotify.com/user/11146430303")!),
        .init(brand: .linkedin,  label: "LinkedIn",  url: URL(string: "https://linkedin.com/in/ardacanbakis")!),
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct BuyMeACoffeeButton: View {
    @Environment(\.openURL) private var openURL
    private let url = URL(string: "https://buymeacoffee.com/ardacanbakis")!

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                Text("Buy me a coffee").fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color(red: 1.0, green: 0.86, blue: 0.0)))
            .foregroundColor(.black)
        }
        .buttonStyle(.plain)
        .help("Support HushBar — opens buymeacoffee.com")
    }
}

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
