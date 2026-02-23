//
//  CalendarViewModel+CRUD.swift
//  ThermoTask
//

import EventKit
import Foundation

extension CalendarViewModel {

    // MARK: - Reminders (Assign/Unassign)

    func assignDate(toReminderWithIdentifier id: String) {
        assignDates(toReminderWithIdentifiers: [id])
    }

    func assignDates(toReminderWithIdentifiers ids: [String]) {
        var didAssign = false
        for id in ids {
            guard let reminder = undatedReminders.first(where: { $0.calendarItemIdentifier == id })
            else { continue }
            do {
                try calendarService.assignDueDate(to: reminder, date: selectedDate)
                didAssign = true
            } catch {
                print("Error assigning due date: \(error.localizedDescription)")
            }
        }
        if didAssign {
            Task { await fetchTodaysData() }
        }
    }

    func unassignDate(fromReminderWithIdentifier id: String, targetCalendar: EKCalendar? = nil) {
        unassignDates(fromReminderWithIdentifiers: [id], targetCalendar: targetCalendar)
    }

    func unassignDates(fromReminderWithIdentifiers ids: [String], targetCalendar: EKCalendar? = nil) {
        var didUnassign = false
        for id in ids {
            guard let reminder = todaysReminders.first(where: { $0.calendarItemIdentifier == id })
            else { continue }
            do {
                try calendarService.unassignDueDate(from: reminder, movingTo: targetCalendar)
                didUnassign = true
            } catch {
                print("Error unassigning due date: \(error.localizedDescription)")
            }
        }
        if didUnassign {
            Task { await fetchTodaysData() }
        }
    }

    // MARK: - Create

    func createEvent(
        title: String,
        location: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        notes: String?,
        calendar: EKCalendar?
    ) {
        do {
            try calendarService.createEvent(
                title: title,
                location: location,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                notes: notes,
                calendar: calendar
            )
            Task { await fetchTodaysData() }
        } catch {
            print("Error creating event: \(error.localizedDescription)")
        }
    }

    func createReminder(
        title: String,
        notes: String?,
        url: URL?,
        dueDateComponents: DateComponents?,
        isUrgent: Bool,
        priority: Int,
        calendar: EKCalendar?
    ) {
        do {
            try calendarService.createReminder(
                title: title,
                notes: notes,
                url: url,
                dueDateComponents: dueDateComponents,
                isUrgent: isUrgent,
                priority: priority,
                calendar: calendar
            )
            Task { await fetchTodaysData() }
        } catch {
            print("Error creating reminder: \(error.localizedDescription)")
        }
    }

    // MARK: - Edit

    func editEvent(
        _ event: EKEvent,
        title: String, location: String?, startDate: Date, endDate: Date,
        isAllDay: Bool, notes: String?, calendar: EKCalendar?
    ) {
        do {
            try calendarService.updateEvent(
                event, title: title, location: location,
                startDate: startDate, endDate: endDate,
                isAllDay: isAllDay, notes: notes, calendar: calendar)
            Task { await fetchTodaysData() }
        } catch {
            print("Error updating event: \(error.localizedDescription)")
        }
    }

    func editReminder(
        _ reminder: EKReminder,
        title: String, notes: String?, url: URL?,
        dueDateComponents: DateComponents?, isUrgent: Bool,
        priority: Int, calendar: EKCalendar?
    ) {
        do {
            try calendarService.updateReminder(
                reminder, title: title, notes: notes, url: url,
                dueDateComponents: dueDateComponents, isUrgent: isUrgent,
                priority: priority, calendar: calendar)
            Task { await fetchTodaysData() }
        } catch {
            print("Error updating reminder: \(error.localizedDescription)")
        }
    }
}
