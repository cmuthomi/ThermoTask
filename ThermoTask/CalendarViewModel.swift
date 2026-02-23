//
//  CalendarViewModel.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import Combine
import EventKit
import Foundation
import SwiftUI

/// ViewModel that manages the state and business logic for calendar data
@MainActor
class CalendarViewModel: ObservableObject {
    @Published var todaysEvents: [EKEvent] = []
    @Published var todaysReminders: [EKReminder] = []
    @Published var undatedReminders: [EKReminder] = []
    @Published var isLoading = false
    @Published var selectedDate: Date
    @Published var showLeftSidebar: Bool = false
    @Published var enabledCalendarIds: Set<String> = []
    @Published var enabledReminderListIds: Set<String> = []
    @Published var allEventCalendars: [EKCalendar] = []
    @Published var allReminderLists: [EKCalendar] = []
    @Published var selectedItems: Set<String> = []
    @Published var showDeleteConfirmation = false

    let calendarService: CalendarService
    private var cancellables = Set<AnyCancellable>()
    var currentFetchTask: Task<Void, Never>?

    static let disabledCalendarIdsKey = "disabledCalendarIds"
    static let disabledReminderListIdsKey = "disabledReminderListIds"

    init(calendarService: CalendarService = CalendarService(), currentDate: Date = Date()) {
        self.calendarService = calendarService
        self.selectedDate = currentDate

        calendarService.storeChangedPublisher
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.currentFetchTask?.cancel()
                self.currentFetchTask = Task {
                    self.calendarService.reset()
                    await self.fetchTodaysData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var hasNoItems: Bool {
        displayedEvents.isEmpty && displayedReminders.isEmpty
    }

    var displayedEvents: [EKEvent] {
        todaysEvents.filter {
            enabledCalendarIds.contains($0.calendar.calendarIdentifier)
        }
    }

    var displayedReminders: [EKReminder] {
        todaysReminders.filter {
            enabledReminderListIds.contains($0.calendar?.calendarIdentifier ?? "")
        }
    }

    var eventCalendarsBySource: [(sourceName: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: allEventCalendars) { $0.source.title }
        return grouped.map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.sourceName < $1.sourceName }
    }

    var reminderListsBySource: [(sourceName: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: allReminderLists) { $0.source.title }
        return grouped.map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.sourceName < $1.sourceName }
    }

    var undatedRemindersByList:
        [(title: String, color: Color, calendar: EKCalendar, reminders: [EKReminder])]
    {
        let grouped = Dictionary(grouping: undatedReminders) {
            $0.calendar?.calendarIdentifier ?? ""
        }
        return allReminderLists
            .filter { enabledReminderListIds.contains($0.calendarIdentifier) }
            .map { cal in
                (
                    title: cal.title,
                    color: Color(cgColor: cal.cgColor),
                    calendar: cal,
                    reminders: grouped[cal.calendarIdentifier] ?? []
                )
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - Authorization

    func requestAccess() async {
        let calendarSuccess = await calendarService.requestCalendarAccess()
        let remindersSuccess = await calendarService.requestRemindersAccess()

        if !calendarSuccess {
            print("Warning: Calendar access not granted")
        }
        if !remindersSuccess {
            print("Warning: Reminders access not granted")
        }
    }

    // MARK: - Fetch Data

    func fetchTodaysData() async {
        isLoading = true
        defer { isLoading = false }

        // Populate available calendars/lists (synchronous)
        allEventCalendars = calendarService.fetchEventCalendars()
        allReminderLists = calendarService.fetchReminderLists()

        // Compute enabled sets: all IDs minus persisted disabled IDs
        let allCalIds = Set(allEventCalendars.map(\.calendarIdentifier))
        let disabledCals = Set(UserDefaults.standard.stringArray(forKey: Self.disabledCalendarIdsKey) ?? [])
        enabledCalendarIds = allCalIds.subtracting(disabledCals)

        let allListIds = Set(allReminderLists.map(\.calendarIdentifier))
        let disabledLists = Set(UserDefaults.standard.stringArray(forKey: Self.disabledReminderListIdsKey) ?? [])
        enabledReminderListIds = allListIds.subtracting(disabledLists)

        // Fetch events synchronously (they're fast)
        todaysEvents = calendarService.fetchEvents(for: selectedDate)

        // Fetch all reminders in one call (EventKit only supports one active fetch at a time)
        let (dated, undated) = await calendarService.fetchAllReminders(for: selectedDate)
        guard !Task.isCancelled else { return }
        todaysReminders = dated
        undatedReminders = undated
    }

    func refresh() async {
        print("Refreshing events and reminders...")
        await fetchTodaysData()
    }

    // MARK: - Calendar/List Filters

    func toggleCalendar(_ id: String) {
        if enabledCalendarIds.contains(id) {
            enabledCalendarIds.remove(id)
        } else {
            enabledCalendarIds.insert(id)
        }
        let allCalIds = Set(allEventCalendars.map(\.calendarIdentifier))
        let disabledCals = Array(allCalIds.subtracting(enabledCalendarIds))
        UserDefaults.standard.set(disabledCals, forKey: Self.disabledCalendarIdsKey)
    }

    func toggleReminderList(_ id: String) {
        if enabledReminderListIds.contains(id) {
            enabledReminderListIds.remove(id)
        } else {
            enabledReminderListIds.insert(id)
        }
        let allListIds = Set(allReminderLists.map(\.calendarIdentifier))
        let disabledLists = Array(allListIds.subtracting(enabledReminderListIds))
        UserDefaults.standard.set(disabledLists, forKey: Self.disabledReminderListIdsKey)
    }
}

#if DEBUG
    extension CalendarViewModel {
        static var preview: CalendarViewModel {
            let vm = CalendarViewModel()
            let store = EKEventStore()

            func makeCalendar(title: String, hex: Int) -> EKCalendar {
                let cal = EKCalendar(for: .reminder, eventStore: store)
                cal.title = title
                cal.cgColor = CGColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
                return cal
            }

            func makeReminder(title: String, calendar: EKCalendar) -> EKReminder {
                let r = EKReminder(eventStore: store)
                r.title = title
                r.calendar = calendar
                return r
            }

            let acquisti = makeCalendar(title: "Acquisti", hex: 0x9B59B6)
            let work = makeCalendar(title: "Work", hex: 0x2980B9)

            vm.undatedReminders = [
                makeReminder(title: "Buy groceries", calendar: acquisti),
                makeReminder(title: "Order new headphones", calendar: acquisti),
                makeReminder(title: "Finish Q1 report", calendar: work),
            ]
            return vm
        }
    }
#endif
