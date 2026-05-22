import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            StyleSettingsView(settings: settings)
                .tabItem { Label("Style", systemImage: "paintbrush") }
            GeneralSettingsView(mic: mic, settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "person.crop.circle") }
        }
        .frame(width: 440)
    }
}

// MARK: - Style

private struct StyleSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Preview") {
                HStack(spacing: 16) {
                    Spacer()
                    preview(on: true)
                    preview(on: false)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Button") {
                Picker("Style", selection: $settings.buttonStyle) {
                    ForEach(PillStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                TextField("On label", text: $settings.onText)
                TextField("Off label", text: $settings.offText)
            }

            Section("Colors") {
                ColorPicker("On color", selection: Binding(
                    get: { Color(nsColor: settings.onColor) },
                    set: { settings.onColor = NSColor($0) }))
                ColorPicker("Off color", selection: Binding(
                    get: { Color(nsColor: settings.offColor) },
                    set: { settings.offColor = NSColor($0) }))
            }

            Section {
                Button("Reset to defaults") { settings.resetStyle() }
            }
        }
        .formStyle(.grouped)
    }

    private func preview(on: Bool) -> some View {
        Image(nsImage: PillRenderer.image(
            style: settings.buttonStyle,
            on: on,
            onText: settings.onText,
            offText: settings.offText,
            onColor: settings.onColor,
            offColor: settings.offColor))
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
            }

            Section {
                Toggle("Launch muteMe at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLogin.isEnabled = newValue
                    }
            }

            Section {
                HStack {
                    Text("Microphone")
                    Spacer()
                    Text(mic.isMuted ? "Muted" : "Live")
                        .foregroundColor(mic.isMuted ? .secondary : Color(nsColor: settings.onColor))
                        .fontWeight(.semibold)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: - About

private struct SocialLink: Identifiable {
    let label: String
    let symbol: String
    let url: URL
    var id: String { label }
}

private struct AboutView: View {
    private let links: [SocialLink] = [
        .init(label: "Website", symbol: "globe", url: URL(string: "https://ardacanbakis.com")!),
        .init(label: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: URL(string: "https://github.com/ardacanbakis")!),
        .init(label: "Instagram", symbol: "camera.fill", url: URL(string: "https://www.instagram.com/arda.canbakiss/")!),
        .init(label: "YouTube", symbol: "play.rectangle.fill", url: URL(string: "https://www.youtube.com/@arda.canbakis")!),
        .init(label: "Spotify", symbol: "music.note", url: URL(string: "https://open.spotify.com/user/11146430303")!),
        .init(label: "LinkedIn", symbol: "briefcase.fill", url: URL(string: "https://linkedin.com/in/ardacanbakis")!),
    ]

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(v)"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            VStack(spacing: 2) {
                Text("muteMe").font(.title2).fontWeight(.bold)
                Text("Mute your microphone from the menu bar.")
                    .font(.callout).foregroundColor(.secondary)
                Text(version).font(.caption).foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                ForEach(links) { link in
                    Link(destination: link.url) {
                        Image(systemName: link.symbol).font(.system(size: 17))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help(link.label)
                }
            }
            .padding(.top, 2)

            footer
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Created with")
            Image(systemName: "heart.fill").foregroundColor(.red)
            Text("by")
            Link("Arda Canbakis", destination: URL(string: "https://ardacanbakis.com")!)
            Text("© 2026")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
