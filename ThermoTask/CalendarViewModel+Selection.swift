//
//  CalendarViewModel+Selection.swift
//  ThermoTask
//

import EventKit

extension CalendarViewModel {

    // MARK: - Selection

    func toggleSelection(_ identifier: String) {
        if selectedItems.contains(identifier) {
            selectedItems.remove(identifier)
        } else {
            selectedItems.insert(identifier)
        }
    }

    func clearSelection() {
        selectedItems.removeAll()
    }

    func isSelected(_ identifier: String) -> Bool {
        selectedItems.contains(identifier)
    }

    var selectedEvents: [EKEvent] {
        displayedEvents.filter { selectedItems.contains($0.eventIdentifier) }
    }

    var selectedReminders: [EKReminder] {
        displayedReminders.filter { selectedItems.contains($0.calendarItemIdentifier) }
    }

    func selectAll() {
        let eventIds = displayedEvents.compactMap(\.eventIdentifier)
        let reminderIds = displayedReminders.map(\.calendarItemIdentifier)
        selectedItems = Set(eventIds + reminderIds)
    }

    // MARK: - Delete

    func deleteSelectedItems() {
        for event in selectedEvents {
            do {
                try calendarService.deleteEvent(event)
            } catch {
                print("Error deleting event: \(error.localizedDescription)")
            }
        }
        for reminder in selectedReminders {
            do {
                try calendarService.deleteReminder(reminder)
            } catch {
                print("Error deleting reminder: \(error.localizedDescription)")
            }
        }
        selectedItems.removeAll()
        Task { await fetchTodaysData() }
    }

    func toggleReminder(_ reminder: EKReminder) {
        do {
            try calendarService.toggleReminderCompletion(reminder)
            Task {
                await fetchTodaysData()
            }
        } catch {
            print("Error updating reminder: \(error.localizedDescription)")
        }
    }
}
