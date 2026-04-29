import SwiftUI

struct EventListView: View {
    let events: [CalendarEvent]
    
    var body: some View {
        List(events) { event in
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                HStack {
                    Text(event.startDate, style: .time)
                    Text("-")
                    Text(event.endDate, style: .time)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(PlainListStyle())
    }
}
