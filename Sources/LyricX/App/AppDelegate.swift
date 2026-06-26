import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    public override init() {}

    public func applicationDidFinishLaunching(_ notification: Notification) {
        container = AppContainer()
    }
}
