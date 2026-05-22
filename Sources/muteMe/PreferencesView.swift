import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
            }

            Section("Appearance") {
                ColorPicker("Live (On) color", selection: Binding(
                    get: { Color(nsColor: settings.onColor) },
                    set: { settings.onColor = NSColor($0) }))
                ColorPicker("Muted (Off) color", selection: Binding(
                    get: { Color(nsColor: settings.offColor) },
                    set: { settings.offColor = NSColor($0) }))
                Button("Reset to defaults") { settings.resetColors() }
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
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
