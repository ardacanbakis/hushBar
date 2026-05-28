import SwiftUI

enum ColorTarget: Equatable { case on, off, onText, offText }

struct ColorEditorPanel: View {
    let title: String
    @Binding var color: ColorComponents
    let onDone: () -> Void

    @State private var hexInput = ""

    private var palette: [ColorComponents] {
        [
            AppSettings.defaultRed,
            AppSettings.defaultGray,
            ColorComponents(r: 1,    g: 1,    b: 1),
            ColorComponents(r: 0.10, g: 0.10, b: 0.10),
            ColorComponents(r: 0.95, g: 0.23, b: 0.17),
            ColorComponents(r: 1.00, g: 0.58, b: 0.00),
            ColorComponents(r: 1.00, g: 0.84, b: 0.00),
            ColorComponents(r: 0.20, g: 0.78, b: 0.35),
            ColorComponents(r: 0.10, g: 0.68, b: 0.68),
            ColorComponents(r: 0.12, g: 0.47, b: 1.00),
            ColorComponents(r: 0.58, g: 0.23, b: 0.93),
            ColorComponents(r: 1.00, g: 0.22, b: 0.54),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Done", action: onDone).controlSize(.small)
            }

            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: color.nsColor))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )

            let cols = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(palette.indices, id: \.self) { i in
                    let swatch = palette[i]
                    Circle()
                        .fill(Color(nsColor: swatch.nsColor))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                        .overlay(
                            Circle().stroke(Color.accentColor, lineWidth: 2)
                                .opacity(swatch == color ? 1 : 0)
                        )
                        .onTapGesture { color = swatch }
                }
            }

            Divider()

            VStack(spacing: 6) {
                colorSlider("R", value: $color.r, tint: .red)
                colorSlider("G", value: $color.g, tint: .green)
                colorSlider("B", value: $color.b, tint: .blue)
                colorSlider("A", value: $color.a, tint: .primary)
            }

            HStack(spacing: 4) {
                Text("#").foregroundColor(.secondary).font(.caption)
                TextField("RRGGBB", text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 72)
                    .onSubmit { applyHex() }
                Button("↵") { applyHex() }.controlSize(.mini)
            }
        }
        .padding(14)
        .frame(width: 215)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .onAppear { hexInput = color.hexString }
        .onChange(of: color) { newColor in hexInput = newColor.hexString }
    }

    @ViewBuilder
    private func colorSlider(_ label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 12)
            Slider(value: value, in: 0...1).tint(tint)
            Text("\(Int((value.wrappedValue * 255).clamped(to: 0...255)))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func applyHex() {
        if let c = ColorComponents(hexString: hexInput) { color = c }
        hexInput = color.hexString
    }
}

// MARK: - ColorComponents hex helpers

extension ColorComponents {
    var hexString: String {
        String(format: "%02X%02X%02X",
               Int((r * 255).clamped(to: 0...255)),
               Int((g * 255).clamped(to: 0...255)),
               Int((b * 255).clamped(to: 0...255)))
    }

    init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6 || s.count == 8,
              let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >>  8) & 0xFF) / 255
            a = Double( value        & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >>  8) & 0xFF) / 255
            b = Double( value        & 0xFF) / 255
            a = 1
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
