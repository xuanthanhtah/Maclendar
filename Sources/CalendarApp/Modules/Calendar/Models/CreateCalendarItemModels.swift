import Foundation

enum CalendarItemType: String, CaseIterable, Identifiable {
    case event = "Event"
    case task = "Task"

    var id: String { rawValue }
}

struct CreateCalendarItemRequest: Sendable {
    let type: CalendarItemType
    let title: String
    let description: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let timeZoneIdentifier: String
}