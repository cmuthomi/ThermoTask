//
//  NewItemView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 20/02/26.
//

import EventKit
import SwiftUI

struct NewItemView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool

    private let editingEvent: EKEvent?
    private let editingReminder: EKReminder?

    @State private var selectedTab = 0

    // Event state
    @State private var eventTitle = ""
    @State private var eventLocation = ""
    @State private var eventNotes = ""
    @State private var eventStartDate: Date
    @State private var eventEndDate: Date
    @State private var eventIsAllDay = false
    @State private var eventCalendar: EKCalendar?

    // Reminder state
    @State private var reminderTitle = ""
    @State private var reminderNotes = ""
    @State private var reminderURLString = ""
    @State private var reminderHasDate: Bool
    @State private var reminderDueDate: Date
    @State private var reminderHasTime = false
    @State private var reminderIsUrgent = false
    @State private var reminderCalendar: EKCalendar?
    @State private var reminderPriority = 0

    init(viewModel: CalendarViewModel, isPresented: Binding<Bool>,
         editingEvent: EKEvent? = nil, editingReminder: EKReminder? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.editingEvent = editingEvent
        self.editingReminder = editingReminder

        let cal = Calendar.current
        let base = viewModel.selectedDate

        if let event = editingEvent {
            _selectedTab = State(initialValue: 0)
            _eventTitle = State(initialValue: event.title ?? "")
            _eventLocation = State(initialValue: event.location ?? "")
            _eventNotes = State(initialValue: event.notes ?? "")
            _eventStartDate = State(initialValue: event.startDate ?? base)
            _eventEndDate = State(initialValue: event.endDate ?? base)
            _eventIsAllDay = State(initialValue: event.isAllDay)
            _eventCalendar = State(initialValue: event.calendar)
            _reminderDueDate = State(initialValue: base)
            _reminderHasDate = State(initialValue: false)
        } else if let reminder = editingReminder {
            _selectedTab = State(initialValue: 1)
            _reminderTitle = State(initialValue: reminder.title ?? "")
            _reminderNotes = State(initialValue: reminder.notes ?? "")
            _reminderURLString = State(initialValue: reminder.url?.absoluteString ?? "")
            let hasDC = reminder.dueDateComponents != nil
            _reminderHasDate = State(initialValue: hasDC)
            let hasTime = hasDC && reminder.dueDateComponents?.hour != nil
            _reminderHasTime = State(initialValue: hasTime)
            let dueDate = reminder.dueDateComponents.flatMap { cal.date(from: $0) } ?? base
            _reminderDueDate = State(initialValue: dueDate)
            _reminderIsUrgent = State(initialValue: !(reminder.alarms?.isEmpty ?? true))
            _reminderCalendar = State(initialValue: reminder.calendar)
            _reminderPriority = State(initialValue: reminder.priority)
            let hour = max(cal.component(.hour, from: Date()) + 1, 9)
            let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
            _eventStartDate = State(initialValue: start)
            _eventEndDate = State(initialValue: cal.date(byAdding: .hour, value: 1, to: start) ?? start)
        } else {
            // Create mode — identical to original
            let hour = max(cal.component(.hour, from: Date()) + 1, 9)
            let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
            _eventStartDate = State(initialValue: start)
            _eventEndDate = State(initialValue: cal.date(byAdding: .hour, value: 1, to: start) ?? start)
            _reminderDueDate = State(initialValue: base)
            _reminderHasDate = State(initialValue: false)
        }
    }

    private var isEditing: Bool { editingEvent != nil || editingReminder != nil }

    private var isAddDisabled: Bool {
        if selectedTab == 0 {
            return eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("Event").tag(0)
                    Text("Reminder").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(isEditing)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    if selectedTab == 0 {
                        saveEvent()
                    } else {
                        saveReminder()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(isAddDisabled ? Color.secondary : Color.accentColor)
                .disabled(isAddDisabled)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if selectedTab == 0 {
                eventForm
            } else {
                reminderForm
            }
        }
        .onAppear {
            if eventCalendar == nil {
                eventCalendar = viewModel.allEventCalendars.first
            }
            if reminderCalendar == nil {
                reminderCalendar = viewModel.allReminderLists.first
            }
        }
        .onChange(of: viewModel.allEventCalendars) { _, calendars in
            if eventCalendar == nil {
                eventCalendar = calendars.first
            }
        }
        .onChange(of: viewModel.allReminderLists) { _, lists in
            if reminderCalendar == nil {
                reminderCalendar = lists.first
            }
        }
    }

    // MARK: - Event Form

    private var eventForm: some View {
        Form {
            Section {
                HStack {
                    TextField("", text: $eventTitle, prompt: Text("New Event"))
                        .font(.body)
                        .labelsHidden()
                }

                Picker(selection: $eventCalendar) {
                    Text("None").tag(EKCalendar?.none)
                    ForEach(viewModel.allEventCalendars, id: \.calendarIdentifier) { cal in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                        .tag(Optional(cal))
                    }
                } label: {
                    Label("Calendar", systemImage: "calendar")
                }

                TextField("", text: $eventLocation, prompt: Text("Add Location or Video Call"))
                    .font(.body)
                    .labelsHidden()
            }

            Section {
                Toggle("All-day", isOn: $eventIsAllDay)

                DatePicker(
                    "Starts",
                    selection: $eventStartDate,
                    displayedComponents: eventIsAllDay ? .date : [.date, .hourAndMinute]
                )
                .onChange(of: eventStartDate) { _, newStart in
                    // Keep end >= start + 1 h
                    if eventEndDate < newStart {
                        eventEndDate =
                            Calendar.current.date(byAdding: .hour, value: 1, to: newStart)
                            ?? newStart
                    }
                }

                DatePicker(
                    "Ends",
                    selection: $eventEndDate,
                    in: eventStartDate...,
                    displayedComponents: eventIsAllDay ? .date : [.date, .hourAndMinute]
                )
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if eventNotes.isEmpty {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                            .padding(.top, 0)
                            .padding(.leading, -1)
                    }
                    TextEditor(text: $eventNotes)
                        .font(.body)
                        .frame(minHeight: 15)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, -5)
                        .scrollContentBackground(.hidden)
                }
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Reminder Form

    private var reminderForm: some View {
        Form {
            Section {
                TextField("", text: $reminderTitle, prompt: Text("Title"))
                    .font(.body)
                    .labelsHidden()

                ZStack(alignment: .topLeading) {
                    if reminderNotes.isEmpty {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                            .padding(.top, 0)
                            .padding(.leading, -1)
                    }
                    TextEditor(text: $reminderNotes)
                        .font(.body)
                        .frame(minHeight: 15)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, -5)
                        .scrollContentBackground(.hidden)
                }
                .labelsHidden()

                TextField("", text: $reminderURLString, prompt: Text("URL"))
                    .textContentType(.URL)
                    .labelsHidden()
            }

            Section("Date & Time") {
                Toggle(isOn: $reminderHasDate) {
                    Label("Date", systemImage: "calendar")
                }
                .onChange(of: reminderHasDate) { _, newVal in
                    if !newVal {
                        reminderHasTime = false
                        reminderIsUrgent = false
                    }
                }

                if reminderHasDate {
                    HStack {
                        Spacer()
                        DatePicker("", selection: $reminderDueDate, displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                    }
                }

                Toggle(isOn: $reminderHasTime) {
                    Label("Time", systemImage: "clock")
                }
                .disabled(!reminderHasDate)
                .onChange(of: reminderHasTime) { _, newVal in
                    if !newVal { reminderIsUrgent = false }
                    if newVal {
                        let comps = Calendar.current.dateComponents(
                            [.hour, .minute], from: reminderDueDate)
                        if comps.hour == 0 && comps.minute == 0 {
                            if let t = Calendar.current.date(
                                bySettingHour: 9, minute: 0, second: 0, of: reminderDueDate)
                            {
                                reminderDueDate = t
                            }
                        }
                    }
                }

                if reminderHasDate && reminderHasTime {
                    HStack {
                        Spacer()
                        DatePicker(
                            "", selection: $reminderDueDate, displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    }
                }

                Toggle(isOn: $reminderIsUrgent) {
                    Label("Urgent", systemImage: "alarm")
                }
                .disabled(!reminderHasDate || !reminderHasTime)
            }

            Section("Organization") {
                Picker(selection: $reminderCalendar) {
                    Text("None").tag(EKCalendar?.none)
                    ForEach(viewModel.allReminderLists, id: \.calendarIdentifier) { cal in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                        .tag(Optional(cal))
                    }
                } label: {
                    Label("List", systemImage: "list.bullet")
                }

                Picker(selection: $reminderPriority) {
                    Text("None").tag(0)
                    Text("Low").tag(9)
                    Text("Medium").tag(5)
                    Text("High").tag(1)
                } label: {
                    Label("Priority", systemImage: "exclamationmark.3")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Save

    private func saveEvent() {
        let trimmed = eventTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let event = editingEvent {
            viewModel.editEvent(
                event, title: trimmed,
                location: eventLocation.isEmpty ? nil : eventLocation,
                startDate: eventStartDate, endDate: eventEndDate,
                isAllDay: eventIsAllDay,
                notes: eventNotes.isEmpty ? nil : eventNotes,
                calendar: eventCalendar)
        } else {
            viewModel.createEvent(
                title: trimmed,
                location: eventLocation.isEmpty ? nil : eventLocation,
                startDate: eventStartDate,
                endDate: eventEndDate,
                isAllDay: eventIsAllDay,
                notes: eventNotes.isEmpty ? nil : eventNotes,
                calendar: eventCalendar
            )
        }

        isPresented = false
    }

    private func saveReminder() {
        let trimmed = reminderTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var dateComponents: DateComponents? = nil
        if reminderHasDate {
            if reminderHasTime {
                dateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: reminderDueDate)
            } else {
                dateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day], from: reminderDueDate)
            }
        }

        if let reminder = editingReminder {
            viewModel.editReminder(
                reminder, title: trimmed,
                notes: reminderNotes.isEmpty ? nil : reminderNotes,
                url: reminderURLString.isEmpty ? nil : URL(string: reminderURLString),
                dueDateComponents: dateComponents,
                isUrgent: reminderIsUrgent && reminderHasDate && reminderHasTime,
                priority: reminderPriority,
                calendar: reminderCalendar)
        } else {
            viewModel.createReminder(
                title: trimmed,
                notes: reminderNotes.isEmpty ? nil : reminderNotes,
                url: reminderURLString.isEmpty ? nil : URL(string: reminderURLString),
                dueDateComponents: dateComponents,
                isUrgent: reminderIsUrgent && reminderHasDate && reminderHasTime,
                priority: reminderPriority,
                calendar: reminderCalendar
            )
        }

        isPresented = false
    }
}
