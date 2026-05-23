import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            TopHalf { GeneralSettingsView(mic: mic, settings: settings) }
                .tabItem { Label("General", systemImage: "gearshape") }
            TopHalf { StyleSettingsView(settings: settings) }
                .tabItem { Label("Style", systemImage: "paintbrush") }
            TopHalf { AboutView() }
                .tabItem { Label("About", systemImage: "person.crop.circle") }
        }
        .frame(width: 470, height: 680)
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

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 14) {
            GroupBox("Global Shortcut") {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
            GroupBox {
                Toggle("Launch muteMe at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in LaunchAtLogin.isEnabled = newValue }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
            GroupBox {
                HStack {
                    Text("Microphone")
                    Spacer()
                    Text(mic.isMuted ? "Muted" : "Live")
                        .foregroundColor(mic.isMuted ? .secondary : Color(nsColor: settings.onColor))
                        .fontWeight(.semibold)
                }
                .padding(6)
            }
        }
        .frame(width: 360)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: - Style

private struct StyleSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            GroupBox("Preview") {
                HStack(spacing: 16) {
                    preview(on: true)
                    preview(on: false)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
            }
            GroupBox("Button") {
                VStack(spacing: 8) {
                    Picker("Style", selection: $settings.buttonStyle) {
                        ForEach(PillStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField("On label", text: $settings.onText)
                    TextField("Off label", text: $settings.offText)
                }
                .padding(6)
            }
            GroupBox("Colors") {
                VStack(spacing: 8) {
                    ColorPicker("On color", selection: Binding(
                        get: { Color(nsColor: settings.onColor) },
                        set: { settings.onColor = NSColor($0) }))
                    ColorPicker("Off color", selection: Binding(
                        get: { Color(nsColor: settings.offColor) },
                        set: { settings.offColor = NSColor($0) }))
                }
                .padding(6)
            }
            Button("Reset to defaults") { settings.resetStyle() }
        }
        .frame(width: 360)
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
                Text("muteMe").font(.title2).fontWeight(.bold)
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
