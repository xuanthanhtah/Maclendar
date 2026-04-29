import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var popover: NSPopover!
    var statusBarController: StatusBarController!
    var viewModel: CalendarViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run on MainActor
        Task { @MainActor in
            viewModel = CalendarViewModel()
            await viewModel.loadTodayEvents()
            await viewModel.loadEvents()

            // Create the SwiftUI view that provides the window contents.
            let contentView = PopoverView(viewModel: viewModel)

            // Create the popover
            popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: contentView)
            popover.contentSize = NSSize(width: 300, height: 400)

            // Create the Status Bar Controller
            statusBarController = StatusBarController(popover: popover, viewModel: viewModel)
        
            // Hide the dock icon, we only want the menu bar icon
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
