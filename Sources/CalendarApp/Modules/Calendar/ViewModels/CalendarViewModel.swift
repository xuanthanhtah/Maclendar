import Foundation
import Combine
import CoreGraphics

enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var items: [CalendarListItem] = []
    @Published var todayEvents: [CalendarEvent] = []  // Always today's events for the menu bar
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var preferredPopoverWidth: CGFloat = 300
    
    @Published var selectedDate: Date = Date()
    @Published var viewMode: CalendarViewMode = .day
    
    private let calendarService = CalendarService()
    private let tasksService = GoogleTasksService()
    
    @Published var isAuthenticated: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        AuthManager.shared.$isAuthenticated
            .receive(on: RunLoop.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
            
        // Observe changes to selectedDate to reload events
        $selectedDate
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadEvents() }
            }
            .store(in: &cancellables)
    }
    
    func login() async {
        do {
            try await AuthManager.shared.login()
            await loadTodayEvents()
            await loadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Load today's events for the menu bar preview (always today, never changes)
    func loadTodayEvents() async {
        guard isAuthenticated else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        do {
            self.todayEvents = try await calendarService.fetchEvents(from: startOfDay, to: endOfDay)
        } catch {
            // Silently fail for menu bar — don't show error
            print("Failed to load today events: \(error)")
        }
    }
    
    /// Load events for the selected day (popover list)
    func loadEvents() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate
            
            async let events = calendarService.fetchEvents(from: startOfDay, to: endOfDay)
            async let tasks = tasksService.fetchTasks(from: startOfDay, to: endOfDay)

            let fetchedEvents = try await events
            let fetchedTasks = try await tasks

            self.events = fetchedEvents
            self.items = combineItems(events: fetchedEvents, tasks: fetchedTasks)
            updatePreferredPopoverWidth()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createCalendarItem(_ request: CreateCalendarItemRequest) async throws {
        guard isAuthenticated else {
            throw NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unauthenticated"])
        }

        switch request.type {
        case .event:
            try await calendarService.createEvent(request: request)
            await loadTodayEvents()
            await loadEvents()
        case .task:
            try await tasksService.createTask(request: request)
            await loadEvents()
        }
    }

    func updateCalendarItem(_ item: CalendarListItem, request: CreateCalendarItemRequest) async throws {
        guard isAuthenticated else {
            throw NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unauthenticated"])
        }

        switch item.kind {
        case .event:
            try await calendarService.updateEvent(id: item.id, request: request)
            await loadTodayEvents()
            await loadEvents()
        case .task:
            try await tasksService.updateTask(id: item.id, request: request)
            await loadEvents()
        }
    }

    func deleteCalendarItem(_ item: CalendarListItem) async throws {
        guard isAuthenticated else {
            throw NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unauthenticated"])
        }

        switch item.kind {
        case .event:
            try await calendarService.deleteEvent(id: item.id)
            await loadTodayEvents()
            await loadEvents()
        case .task:
            try await tasksService.deleteTask(id: item.id)
            await loadEvents()
        }
    }

    private func combineItems(events: [CalendarEvent], tasks: [CalendarTaskItem]) -> [CalendarListItem] {
        let eventItems = events.map { event in
            CalendarListItem(
                id: event.id,
                kind: .event,
                title: event.title,
                notes: event.description,
                startDate: event.startDate,
                endDate: event.endDate,
                dueDate: nil,
                isAllDay: event.isAllDay
            )
        }

        let taskItems = tasks.map { task in
            CalendarListItem(
                id: task.id,
                kind: .task,
                title: task.title,
                notes: task.notes,
                startDate: nil,
                endDate: nil,
                dueDate: task.dueDate,
                isAllDay: true
            )
        }

        return (eventItems + taskItems).sorted { $0.displayDate < $1.displayDate }
    }

    private func updatePreferredPopoverWidth() {
        let visibleItems = items.filter { $0.kind == .event }

        guard !visibleItems.isEmpty else {
            preferredPopoverWidth = 300
            return
        }

        let longestTitle = visibleItems.map { $0.title.count }.max() ?? 0
        let longestSecondary = visibleItems.map { $0.secondaryText.count }.max() ?? 0
        let longestNotes = visibleItems.compactMap { $0.notes?.count }.max() ?? 0

        let estimatedWidth = 220 + (longestTitle * 6) + (longestSecondary * 3) + (longestNotes * 2)
        preferredPopoverWidth = CGFloat(min(max(estimatedWidth, 100), 300))
    }
}
