import Foundation

@MainActor
final class AppContainer {
    let model: AppModel

    init() {
        self.model = AppModel()
    }
}
