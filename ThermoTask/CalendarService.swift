//
//  CalendarService.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import Foundation

/// Service responsible for interacting with EventKit
final class CalendarService {
    private let eventStore = EKEventStore()

    var storeChangedPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)
    }

    func reset() {
        eventStore.reset()
    }

    nonisolated init() {
    }

    // MARK: - Authorization

    func requestCalendarAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { success, error in
                if success {
                    print("Calendar access granted")
                } else if let error = error {
                    print("Calendar access denied: \(error.localizedDescription)")
                }
                continuation.resume(returning: success)
            }
        }
    }

    func requestRemindersAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToReminders { success, error in
                if success {
                    print("Reminders access granted")
                } else if let error = error {
                    print("Reminders access denied: \(error.localizedDescription)")
                }
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Fetch Calendars

    func fetchEventCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    func fetchReminderLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
    }

    // MARK: - Fetch Events

    func fetchEvents(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        return events.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Fetch Reminders

    /// Fetches all reminders in a single EventKit call and splits them into
    /// dated-today and undated buckets. Using two separate fetchReminders calls
    /// is unreliable because EventKit only supports one active fetch at a time.
    func fetchAllReminders(for date: Date) async -> (dated: [EKReminder], undated: [EKReminder]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: eventStore.predicateForReminders(in: nil)) {
                reminders in
                let all = reminders ?? []

                let dated =
                    all
                    .filter { reminder in
                        guard !reminder.isCompleted,
                            let dueDateComponents = reminder.dueDateComponents,
                            let dueDate = dueDateComponents.date
                        else { return false }
                        let dueDateStartOfDay = calendar.startOfDay(for: dueDate)
                        return calendar.isDate(dueDateStartOfDay, inSameDayAs: startOfDay)
                    }
                    .sorted {
                        guard let d1 = $0.dueDateComponents?.date,
                            let d2 = $1.dueDateComponents?.date
                        else { return false }
                        return d1 < d2
                    }

                let undated =
                    all
                    .filter { $0.dueDateComponents == nil && !$0.isCompleted }
                    .sorted { ($0.title ?? "") < ($1.title ?? "") }

                continuation.resume(returning: (dated, undated))
            }
        }
    }

    // MARK: - Update Reminders

    func toggleReminderCompletion(_ reminder: EKReminder) throws {
        reminder.isCompleted.toggle()
        try eventStore.save(reminder, commit: true)
    }

    func assignDueDate(to reminder: EKReminder, date: Date) throws {
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day], from: date)
        try eventStore.save(reminder, commit: true)
    }

    func unassignDueDate(from reminder: EKReminder, movingTo calendar: EKCalendar? = nil) throws {
        reminder.dueDateComponents = nil
        if let calendar { reminder.calendar = calendar }
        try eventStore.save(reminder, commit: true)
    }

    func createEvent(
        title: String,
        location: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        notes: String?,
        calendar: EKCalendar?
    ) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.location = location?.isEmpty == false ? location : nil
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.notes = notes?.isEmpty == false ? notes : nil
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func createReminder(
        title: String,
        notes: String?,
        url: URL?,
        dueDateComponents: DateComponents?,
        isUrgent: Bool,
        priority: Int,
        calendar: EKCalendar?
    ) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.url = url
        reminder.dueDateComponents = dueDateComponents
        reminder.priority = priority

        if isUrgent, let components = dueDateComponents, let date = Calendar.current.date(from: components) {
            reminder.addAlarm(EKAlarm(absoluteDate: date))
        }

        reminder.calendar = calendar ?? eventStore.defaultCalendarForNewReminders()
        try eventStore.save(reminder, commit: true)
    }

    func updateEvent(
        _ event: EKEvent,
        title: String, location: String?, startDate: Date, endDate: Date,
        isAllDay: Bool, notes: String?, calendar: EKCalendar?
    ) throws {
        event.title = title
        event.location = location?.isEmpty == false ? location : nil
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.notes = notes?.isEmpty == false ? notes : nil
        if let cal = calendar { event.calendar = cal }
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func updateReminder(
        _ reminder: EKReminder,
        title: String, notes: String?, url: URL?,
        dueDateComponents: DateComponents?, isUrgent: Bool,
        priority: Int, calendar: EKCalendar?
    ) throws {
        reminder.title = title
        reminder.notes = notes
        reminder.url = url
        reminder.dueDateComponents = dueDateComponents
        reminder.priority = priority
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        if isUrgent, let dc = dueDateComponents,
           let date = Calendar.current.date(from: dc) {
            reminder.addAlarm(EKAlarm(absoluteDate: date))
        }
        if let cal = calendar { reminder.calendar = cal }
        try eventStore.save(reminder, commit: true)
    }

    // MARK: - Delete

    func deleteEvent(_ event: EKEvent) throws {
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    func deleteReminder(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
    }
}
