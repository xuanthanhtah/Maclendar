import Foundation

enum CalendarListItemKind: String, CaseIterable, Identifiable, Sendable {
    case event = "Event"
    case task = "Task"

    var id: String { rawValue }
}

struct CalendarListItem: Identifiable, Sendable {
    let id: String
    let kind: CalendarListItemKind
    let title: String
    let notes: String?
    let startDate: Date?
    let endDate: Date?
    let dueDate: Date?
    let isAllDay: Bool

    var displayDate: Date {
        startDate ?? dueDate ?? endDate ?? Date()
    }

    var secondaryText: String {
        switch kind {
        case .event:
            return isAllDay ? "All-day event" : timeRangeText
        case .task:
            return dueDateText
        }
    }

    private var timeRangeText: String {
        guard let startDate, let endDate else { return "No time" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    private var dueDateText: String {
        guard let dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Due \(formatter.string(from: dueDate))"
    }
}