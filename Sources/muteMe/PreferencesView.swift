import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @ObservedObject var mic: MicMuteController
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
            } header: {
                Text("Global Shortcut")
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
                        .foregroundColor(mic.isMuted ? .secondary : .red)
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
