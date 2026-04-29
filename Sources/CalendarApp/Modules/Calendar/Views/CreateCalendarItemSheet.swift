import SwiftUI

struct CreateCalendarItemSheet: View {
    @Environment(\.presentationMode) private var presentationMode

    let initialDate: Date
    let existingItem: CalendarListItem?
    let onSave: (CreateCalendarItemRequest) async throws -> Void
    let onDelete: (() async throws -> Void)?

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool = false
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?

    init(
        initialDate: Date,
        existingItem: CalendarListItem? = nil,
        onSave: @escaping (CreateCalendarItemRequest) async throws -> Void,
        onDelete: (() async throws -> Void)? = nil
    ) {
        self.initialDate = initialDate
        self.existingItem = existingItem
        self.onSave = onSave
        self.onDelete = onDelete

        let defaultStart = existingItem?.startDate ?? initialDate
        let defaultEnd = existingItem?.endDate ?? existingItem?.dueDate ?? Calendar.current.date(byAdding: .minute, value: 30, to: defaultStart) ?? defaultStart

        _title = State(initialValue: existingItem?.title ?? "")
        _descriptionText = State(initialValue: existingItem?.notes ?? "")
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)
        _isAllDay = State(initialValue: existingItem?.isAllDay ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            fieldLabel("Title")
            TextField("Enter title", text: $title)
                .textFieldStyle(.roundedBorder)

            if !isTitleValid {
                validationText("Title is required")
            }

            fieldLabel("Description")
            TextEditor(text: $descriptionText)
                .frame(minHeight: 72, maxHeight: 88)
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            Divider()

            Toggle("All-day", isOn: $isAllDay)

            DatePicker(
                "Start",
                selection: $startDate,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )

            DatePicker(
                "End",
                selection: $endDate,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )

            if !isDateRangeValid {
                validationText("Start must be earlier than end")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if existingItem != nil, let onDelete {
                    Button(action: {
                        Task { await deleteItem(onDelete: onDelete) }
                    }) {
                        Text("Delete")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                    .disabled(isSaving || isDeleting)
                }

                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }

                Button(existingItem == nil ? "Create" : "Save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid || isSaving || isDeleting)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 380, height: 430)
        .onChange(of: startDate) { newValue in
            if endDate <= newValue {
                endDate = Calendar.current.date(byAdding: .minute, value: 30, to: newValue) ?? newValue
            }
        }
        .onChange(of: isAllDay) { newValue in
            if newValue {
                startDate = Calendar.current.startOfDay(for: startDate)
                endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(existingItem == nil ? "Create Event" : "Event Details")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            if isAllDay {
                Text("All-day")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.14))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.red)
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDateRangeValid: Bool {
        endDate > startDate
    }

    private var isFormValid: Bool {
        isTitleValid && isDateRangeValid
    }

    private func save() async {
        guard isFormValid else { return }

        isSaving = true
        errorMessage = nil

        let request = CreateCalendarItemRequest(
            type: .event,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )

        do {
            try await onSave(request)
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func deleteItem(onDelete: @escaping () async throws -> Void) async {
        isDeleting = true
        errorMessage = nil

        do {
            try await onDelete()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeleting = false
    }
}