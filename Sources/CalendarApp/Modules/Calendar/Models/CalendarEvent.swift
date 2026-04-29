import Foundation

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?
    let isAllDay: Bool
}
