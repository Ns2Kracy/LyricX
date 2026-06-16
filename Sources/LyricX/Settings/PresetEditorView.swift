import LyricXCore
import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: LyricStylePreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $preset.name)

            HStack(spacing: 12) {
                Text("Menu Bar Width")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $preset.menuBarWidth, in: 160...420, step: 10)

                Text("\(Int(preset.menuBarWidth)) px")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text("Font Size")
                    .frame(width: 120, alignment: .leading)

                Stepper(value: $preset.fontSize, in: 10...28, step: 1) {
                    Text("\(Int(preset.fontSize)) pt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Text("Font Weight")
                    .frame(width: 120, alignment: .leading)

                Picker("Font Weight", selection: $preset.fontWeight) {
                    Text("Regular").tag("regular")
                    Text("Medium").tag("medium")
                    Text("Semibold").tag("semibold")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Text("Text Color")
                    .frame(width: 120, alignment: .leading)

                TextField("#FFFFFF", text: $preset.textColorHex)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(colorPreview)
                    .frame(width: 28, height: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(.separator, lineWidth: 1)
                    }
                    .accessibilityLabel("Text color preview")
            }

            HStack(spacing: 12) {
                Text("Alignment")
                    .frame(width: 120, alignment: .leading)

                Picker("Alignment", selection: $preset.alignment) {
                    Text("Leading").tag(LyricAlignment.leading)
                    Text("Center").tag(LyricAlignment.center)
                    Text("Trailing").tag(LyricAlignment.trailing)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Toggle("Show track when lyrics are missing", isOn: $preset.showsTrackWhenLyricsMissing)
        }
    }

    private var colorPreview: Color {
        Color(hex: preset.textColorHex) ?? .primary
    }
}

private extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
