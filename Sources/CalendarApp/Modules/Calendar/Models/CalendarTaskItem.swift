import Foundation

struct CalendarTaskItem: Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let completed: Bool
}
