import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    private let calendar = Calendar.current
    @State private var activeSheet: CalendarSheetDestination?
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                        // Left: Title + Today badge
                        HStack(spacing: 8) {
                            Text(headerTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if !calendar.isDateInToday(viewModel.selectedDate) {
                                Button(action: {
                                    viewModel.selectedDate = Date()
                                }) {
                                    Text("Today")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Action buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                activeSheet = .create
                            }) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Add Event")

                            Button(action: {
                                Task {
                                    await viewModel.loadTodayEvents()
                                    await viewModel.loadEvents()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Refresh")
                            
                            Button(action: {
                                AuthManager.shared.logout()
                                viewModel.events = []
                                viewModel.todayEvents = []
                            }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Sign Out")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    
                        Divider()
                        
                        // Day Navigation
                        MiniCalendarView(viewModel: viewModel)
                        
                        Divider()
                        
                        // Event list (scrollable, fixed area)
                        ScrollView {
                            if viewModel.isLoading {
                                VStack {
                                    Spacer(minLength: 80)
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Spacer(minLength: 80)
                                }
                                .frame(maxWidth: .infinity)
                            } else if let error = viewModel.errorMessage {
                                VStack(spacing: 8) {
                                    Spacer(minLength: 50)
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    Spacer(minLength: 50)
                                }
                                .frame(maxWidth: .infinity)
                            } else if visibleEvents.isEmpty {
                                VStack(spacing: 8) {
                                    Spacer(minLength: 60)
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("No events")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    Spacer(minLength: 60)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(visibleEvents) { item in
                                        Button(action: {
                                            activeSheet = .edit(item)
                                        }) {
                                            CalendarListRow(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }

                }
                .sheet(item: $activeSheet) { destination in
                    switch destination {
                    case .create:
                        CreateCalendarItemSheet(
                            initialDate: viewModel.selectedDate,
                            onSave: { request in
                                try await viewModel.createCalendarItem(request)
                            }
                        )
                    case .edit(let item):
                        CreateCalendarItemSheet(
                            initialDate: item.displayDate,
                            existingItem: item,
                            onSave: { request in
                                try await viewModel.updateCalendarItem(item, request: request)
                            },
                            onDelete: {
                                try await viewModel.deleteCalendarItem(item)
                            }
                        )
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "calendar.badge.exclamationmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundColor(.blue)
                    
                    Text("Google Calendar")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("Sign in to view your upcoming events.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 11))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        Task { await viewModel.login() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle")
                            Text("Sign In with Google")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400, alignment: .leading)
        .onAppear {
            Task {
                await viewModel.loadTodayEvents()
                await viewModel.loadEvents()
            }
        }
    }
    
    private var headerTitle: String {
        if calendar.isDateInToday(viewModel.selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(viewModel.selectedDate) {
            return "Tomorrow"
        } else {
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return f.string(from: viewModel.selectedDate)
        }
    }

    private var visibleEvents: [CalendarListItem] {
        viewModel.items.filter { $0.kind == .event }
    }
}

enum CalendarSheetDestination: Identifiable {
    case create
    case edit(CalendarListItem)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let item):
            return "edit-\(item.id)"
        }
    }
}

struct CalendarListRow: View {
    let item: CalendarListItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.kind == .task ? Color.green.opacity(0.16) : Color.blue.opacity(0.16))
                    .frame(width: 34, height: 34)

                Image(systemName: item.kind == .task ? "checklist" : "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.kind == .task ? .green : .blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Spacer(minLength: 0)

                    Text(item.kind.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(item.kind == .task ? .green : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((item.kind == .task ? Color.green : Color.blue).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(item.secondaryText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
