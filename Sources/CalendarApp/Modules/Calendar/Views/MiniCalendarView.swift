import SwiftUI

struct MiniCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            VStack(spacing: 1) {
                Text(dayOfWeekString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(dateString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isToday ? .blue : .primary)
            }
            
            Spacer()
            
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var isToday: Bool {
        calendar.isDateInToday(viewModel.selectedDate)
    }
    
    private var dayOfWeekString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: viewModel.selectedDate)
    }
    
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM, yyyy"
        return f.string(from: viewModel.selectedDate)
    }
    
    private func previousDay() {
        viewModel.selectedDate = calendar.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
    }
    
    private func nextDay() {
        viewModel.selectedDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
    }
}
