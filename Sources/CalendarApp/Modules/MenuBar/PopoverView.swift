import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CalendarViewModel
    var body: some View {
        CalendarView(viewModel: viewModel)
    }
}
