import Foundation

protocol CalendarServiceProtocol: Sendable {
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent]
    func createEvent(request: CreateCalendarItemRequest) async throws
    func updateEvent(id: String, request: CreateCalendarItemRequest) async throws
    func deleteEvent(id: String) async throws
}

protocol GoogleTasksServiceProtocol: Sendable {
    func fetchTasks(from startDate: Date, to endDate: Date) async throws -> [CalendarTaskItem]
    func createTask(request: CreateCalendarItemRequest) async throws
    func updateTask(id: String, request: CreateCalendarItemRequest) async throws
    func deleteTask(id: String) async throws
}

final class CalendarService: CalendarServiceProtocol, Sendable {
    private let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        let timeMinString = formatter.string(from: startDate)
        let timeMaxString = formatter.string(from: endDate)

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMinString),
            URLQueryItem(name: "timeMax", value: timeMaxString),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        let request = try await authorizedRequest(url: url)
        let (data, _) = try await performAuthorizedDataTask(request)

        return try parseEvents(from: data)
    }
    
    private func parseEvents(from data: Data) throws -> [CalendarEvent] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var parsedEvents: [CalendarEvent] = []
        for item in items {
            guard let id = item["id"] as? String,
                  let title = item["summary"] as? String else { continue }
            
            let description = item["description"] as? String
            var isAllDay = false
            
            // Handle start and end
            var startDate = Date()
            var endDate = Date()
            
            if let startDict = item["start"] as? [String: Any],
               let startDateTimeStr = startDict["dateTime"] as? String,
               let date = formatter.date(from: startDateTimeStr) {
                startDate = date
            } else if let startDict = item["start"] as? [String: Any],
                      let startDateStr = startDict["date"] as? String {
                // All day event format "YYYY-MM-DD"
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                isAllDay = true
                if let d = df.date(from: startDateStr) { startDate = d }
            }
            
            if let endDict = item["end"] as? [String: Any],
               let endDateTimeStr = endDict["dateTime"] as? String,
               let date = formatter.date(from: endDateTimeStr) {
                endDate = date
            } else if let endDict = item["end"] as? [String: Any],
                      let endDateStr = endDict["date"] as? String {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                if let d = df.date(from: endDateStr) { endDate = d }
            }
            
            parsedEvents.append(
                CalendarEvent(
                    id: id,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    description: description,
                    isAllDay: isAllDay
                )
            )
        }
        
        return parsedEvents
    }
    
    func createEvent(request: CreateCalendarItemRequest) async throws {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }

        let body: [String: Any] = [
            "summary": request.title,
            "description": request.description,
            "start": eventDatePayload(for: request.startDate, isAllDay: request.isAllDay, timeZoneIdentifier: request.timeZoneIdentifier),
            "end": eventDatePayload(for: request.endDate, isAllDay: request.isAllDay, timeZoneIdentifier: request.timeZoneIdentifier)
        ]

        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        _ = try await performAuthorizedDataTask(httpRequest)
    }

    func updateEvent(id: String, request: CreateCalendarItemRequest) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }

        let body: [String: Any] = [
            "summary": request.title,
            "description": request.description,
            "start": eventDatePayload(for: request.startDate, isAllDay: request.isAllDay, timeZoneIdentifier: request.timeZoneIdentifier),
            "end": eventDatePayload(for: request.endDate, isAllDay: request.isAllDay, timeZoneIdentifier: request.timeZoneIdentifier)
        ]

        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        _ = try await performAuthorizedDataTask(httpRequest)
    }

    func deleteEvent(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "DELETE"
        _ = try await performAuthorizedDataTask(httpRequest)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        guard let token = await AuthManager.shared.getAccessToken() else {
            throw NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unauthenticated"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performAuthorizedDataTask(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let newToken = try await AuthManager.shared.refreshAccessToken()
            var refreshedRequest = request
            refreshedRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: refreshedRequest)
        }

        return (data, response)
    }

    private func eventDatePayload(for date: Date, isAllDay: Bool, timeZoneIdentifier: String) -> [String: Any] {
        if isAllDay {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
            formatter.dateFormat = "yyyy-MM-dd"

            return ["date": formatter.string(from: date)]
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [
            "dateTime": formatter.string(from: date),
            "timeZone": timeZoneIdentifier
        ]
    }

}

final class GoogleTasksService: GoogleTasksServiceProtocol, Sendable {
    private let baseURL = "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks"

    func fetchTasks(from startDate: Date, to endDate: Date) async throws -> [CalendarTaskItem] {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "showCompleted", value: "true"),
            URLQueryItem(name: "showHidden", value: "true"),
            URLQueryItem(name: "maxResults", value: "100")
        ]

        let requestURL = components.url ?? url
        let request = try await authorizedRequest(url: requestURL)
        let (data, _) = try await performAuthorizedDataTask(request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String else { return nil }

            let notes = item["notes"] as? String
            let completed = (item["status"] as? String) == "completed"
            let dueDate = (item["due"] as? String).flatMap { formatter.date(from: $0) }

            if let dueDate {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: startDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? endDate
                guard dueDate >= startOfDay && dueDate < endOfDay else { return nil }
            } else {
                guard startDate <= endDate else { return nil }
            }

            return CalendarTaskItem(id: id, title: title, notes: notes, dueDate: dueDate, completed: completed)
        }
    }

    func createTask(request: CreateCalendarItemRequest) async throws {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }

        let body: [String: Any] = [
            "title": request.title,
            "notes": buildNotes(from: request),
            "due": iso8601Timestamp(for: request.endDate),
            "status": "needsAction"
        ]

        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        _ = try await performAuthorizedDataTask(httpRequest)
    }

    func updateTask(id: String, request: CreateCalendarItemRequest) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }

        let body: [String: Any] = [
            "title": request.title,
            "notes": buildNotes(from: request),
            "due": iso8601Timestamp(for: request.endDate),
            "status": "needsAction"
        ]

        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        _ = try await performAuthorizedDataTask(httpRequest)
    }

    func deleteTask(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        var httpRequest = try await authorizedRequest(url: url)
        httpRequest.httpMethod = "DELETE"
        _ = try await performAuthorizedDataTask(httpRequest)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        guard let token = await AuthManager.shared.getAccessToken() else {
            throw NSError(domain: "TasksError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unauthenticated"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performAuthorizedDataTask(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let newToken = try await AuthManager.shared.refreshAccessToken()
            var refreshedRequest = request
            refreshedRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: refreshedRequest)
        }

        return (data, response)
    }

    private func buildNotes(from request: CreateCalendarItemRequest) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let startLine = "Start: \(formatter.string(from: request.startDate))"
        let endLine = "End: \(formatter.string(from: request.endDate))"
        let descriptionLine = request.description.isEmpty ? nil : request.description

        return ([startLine, endLine, descriptionLine].compactMap { $0 }).joined(separator: "\n")
    }

    private func iso8601Timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
