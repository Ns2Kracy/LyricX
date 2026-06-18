import Foundation

@MainActor
final class AppContainer {
    let model: AppModel
    let mainWindowController: MainWindowController
    let menuBarController: MenuBarStatusItemController
    let floatingLyricsController: FloatingLyricsController

    init() {
        let model = AppModel()
        let mainWindowController = MainWindowController(model: model)

        self.model = model
        self.mainWindowController = mainWindowController
        self.floatingLyricsController = FloatingLyricsController(model: model)
        self.menuBarController = MenuBarStatusItemController(model: model) {
            mainWindowController.showWindow()
        }
    }
}
