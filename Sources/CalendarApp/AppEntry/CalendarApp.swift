import SwiftUI

@main
struct CalendarApp: App {
    // Connect the AppDelegate to the SwiftUI App lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use Settings to avoid opening a main window by default,
        // since this is a menu bar only app.
        Settings {
            EmptyView()
        }
    }
}
