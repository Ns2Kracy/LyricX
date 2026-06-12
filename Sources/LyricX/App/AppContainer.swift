import Foundation

@MainActor
final class AppContainer {
    let model: AppModel
    let floatingLyricsController: FloatingLyricsController

    init() {
        let model = AppModel()
        self.model = model
        self.floatingLyricsController = FloatingLyricsController(model: model)
    }
}
