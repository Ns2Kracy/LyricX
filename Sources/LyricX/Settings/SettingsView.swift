import LyricXCore
import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Lyrics") {
                Picker("Preset", selection: $model.activeStylePresetID) {
                    ForEach(model.stylePresets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .onChange(of: model.activeStylePresetID) { _, newValue in
                    guard let preset = model.stylePresets.first(where: { $0.id == newValue }) else {
                        return
                    }
                    model.selectPreset(preset)
                }

                PresetEditorView(preset: activePresetBinding)
            }

            Section("Menu Bar") {
                Picker("Animation Frame Rate", selection: $model.menuBarFrameRate) {
                    ForEach(MenuBarAnimationFrameRate.allCases) { frameRate in
                        Text(frameRate.label).tag(frameRate)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Player") {
                LabeledContent("Music App") {
                    Label("Spotify", systemImage: "checkmark.circle.fill")
                }

                disabledPlayerRow("Apple Music")
                disabledPlayerRow("NetEase Cloud Music")
                disabledPlayerRow("QQ Music")
                disabledPlayerRow("Browser Players")
            }

            Section("Updates") {
                HStack(spacing: 12) {
                    Text(model.updateStatus)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        model.checkForUpdates()
                    } label: {
                        Label("Check", systemImage: "arrow.down.circle")
                    }

                    if let pageURL = model.latestUpdate?.pageURL {
                        Link(destination: pageURL) {
                            Label("Open Release", systemImage: "safari")
                        }
                    }
                }
            }

        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 360, idealHeight: 420)
    }

    private var activePresetBinding: Binding<LyricStylePreset> {
        Binding(
            get: { model.activeStylePreset },
            set: { model.updatePreset($0) }
        )
    }

    private func disabledPlayerRow(_ name: String) -> some View {
        LabeledContent(name) {
            Label("Not Enabled", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        }
        .disabled(true)
    }

    private func offsetStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: -5000...5000, step: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
