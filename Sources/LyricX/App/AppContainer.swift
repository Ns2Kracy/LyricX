import Foundation

@MainActor
final class AppContainer {
    let model: AppModel
    let mainWindowController: MainWindowController
    let menuBarController: MenuBarStatusItemController

    init() {
        let model = AppModel()
        let mainWindowController = MainWindowController(model: model)

        self.model = model
        self.mainWindowController = mainWindowController
        self.menuBarController = MenuBarStatusItemController(model: model) {
            mainWindowController.showWindow()
        }
    }
}
