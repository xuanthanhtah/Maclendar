import AppKit
import SwiftUI
import Combine

class GlobalEventMonitor {
    private var monitor: Any?
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: GlobalEventMonitor?
    private var viewModel: CalendarViewModel
    private var cancellables = Set<AnyCancellable>()
    private var lastPopoverWidth: CGFloat = 300
    private let minStatusLength: CGFloat = 44
    private let maxStatusLength: CGFloat = 180
    
    init(popover: NSPopover, viewModel: CalendarViewModel) {
        self.popover = popover
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(sender:))
            button.target = self
        }
        
        setupEventMonitor()
        observeEvents()
    }
    
    private func observeEvents() {
        // Only observe todayEvents for the menu bar text (never changes when browsing days)
        viewModel.$todayEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.updateMenuBarText(with: events)
            }
            .store(in: &cancellables)

        viewModel.$preferredPopoverWidth
            .receive(on: RunLoop.main)
            .sink { [weak self] width in
                guard let self else { return }
                self.lastPopoverWidth = width
                if !self.popover.isShown {
                    self.popover.contentSize = NSSize(width: width, height: self.popover.contentSize.height)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarText(with events: [CalendarEvent]) {
        guard let button = statusItem.button else { return }
        
        let now = Date()
        let upcomingEvent = events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
        
        if let event = upcomingEvent {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: event.startDate)
            
            // Truncate title if too long
            let title = event.title
            let maxTitleLength = 20
            let truncatedTitle = title.count > maxTitleLength
                ? String(title.prefix(maxTitleLength)) + "…"
                : title
            
            button.title = " \(timeString) \(truncatedTitle)"
        } else {
            button.title = ""
        }

        updateStatusItemWidth(for: button)
    }
    
    @objc func togglePopover(sender: AnyObject) {
        if popover.isShown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject) {
        if let button = statusItem.button {
            popover.contentSize = NSSize(width: lastPopoverWidth, height: popover.contentSize.height)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    func hidePopover(_ sender: AnyObject) {
        popover.performClose(sender)
    }

    private func setupEventMonitor() {
        eventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                if let popover = self?.popover, popover.isShown {
                    self?.hidePopover(event)
                }
            }
        }
    }

    private func updateStatusItemWidth(for button: NSStatusBarButton) {
        button.sizeToFit()

        let measuredWidth = button.frame.width
        let clampedWidth = min(max(measuredWidth, minStatusLength), maxStatusLength)

        if abs(statusItem.length - clampedWidth) > 0.5 {
            statusItem.length = clampedWidth
        }
    }
}
