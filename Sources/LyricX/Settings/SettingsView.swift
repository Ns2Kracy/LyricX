import LyricXCore
import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SettingsSection = .lyrics

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case lyrics
        case translation
        case menuBar
        case player
        case updates

        var id: Self { self }

        var title: String {
            switch self {
            case .lyrics:
                return "Lyrics"
            case .translation:
                return "Translation"
            case .menuBar:
                return "Menu Bar"
            case .player:
                return "Player"
            case .updates:
                return "Updates"
            }
        }

        var systemImage: String {
            switch self {
            case .lyrics:
                return "text.quote"
            case .translation:
                return "globe"
            case .menuBar:
                return "menubar.rectangle"
            case .player:
                return "music.note"
            case .updates:
                return "arrow.down.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Form {
                switch selection {
                case .lyrics:
                    lyricsSection
                case .translation:
                    translationSection
                case .menuBar:
                    menuBarSection
                case .player:
                    playerSection
                case .updates:
                    updatesSection
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .navigationTitle(selection.title)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 420, idealHeight: 500)
    }

    private var lyricsSection: some View {
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
    }

    private var translationSection: some View {
        Section("Translation") {
            Toggle("Enable lyric translation", isOn: $model.translationEnabled)

            Picker("Target Language", selection: $model.translationTargetLanguage) {
                ForEach(TranslationLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .disabled(!model.translationEnabled)

            Picker("Menu Bar Lyrics", selection: $model.menuBarLyricDisplayMode) {
                ForEach(MenuBarLyricDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Toggle("Show Japanese romaji", isOn: $model.japaneseRomajiEnabled)

            Picker("Translation Source", selection: $model.translationSourceMode) {
                ForEach(TranslationSourceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .disabled(!model.translationEnabled)

            Toggle("NetEase Cloud Music", isOn: $model.netEaseTranslationSourceEnabled)
                .disabled(true)
            Toggle("QQ Music", isOn: $model.qqMusicTranslationSourceEnabled)
                .disabled(true)

            Picker("Machine Provider", selection: $model.machineTranslationProvider) {
                ForEach(MachineTranslationProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .disabled(!model.translationEnabled)

            if model.machineTranslationProvider == .openAICompatible {
                TextField("Base URL", text: $model.openAICompatibleBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model.openAICompatibleModel)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $model.openAICompatibleAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            Text("NetEase and QQ Music sources are visible for the Chinese-lyrics roadmap but disabled until their APIs are implemented. OpenAI-compatible providers can translate to any configured target language.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(model.translationStatus.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var menuBarSection: some View {
        Section("Menu Bar") {
            Picker("Animation Frame Rate", selection: $model.menuBarFrameRate) {
                ForEach(MenuBarAnimationFrameRate.allCases) { frameRate in
                    Text(frameRate.label).tag(frameRate)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var playerSection: some View {
        Section("Player") {
            LabeledContent("Music App") {
                Label("Spotify", systemImage: "checkmark.circle.fill")
            }

            disabledPlayerRow("Apple Music")
            disabledPlayerRow("NetEase Cloud Music")
            disabledPlayerRow("QQ Music")
            disabledPlayerRow("Browser Players")
        }
    }

    private var updatesSection: some View {
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
