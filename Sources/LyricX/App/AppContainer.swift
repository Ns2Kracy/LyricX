import Foundation

@MainActor
final class AppContainer {
    let model: AppModel
    let mainWindowController: MainWindowController
    let menuBarController: MenuBarStatusItemController
    let floatingLyricsController: FloatingLyricsController
    let islandLyricsController: IslandLyricsController

    init() {
        let model = AppModel()
        let mainWindowController = MainWindowController(model: model)

        self.model = model
        self.mainWindowController = mainWindowController
        self.floatingLyricsController = FloatingLyricsController(model: model)
        self.islandLyricsController = IslandLyricsController(model: model) {
            mainWindowController.showWindow()
        }
        self.menuBarController = MenuBarStatusItemController(model: model) {
            mainWindowController.showWindow()
        }
    }
}
