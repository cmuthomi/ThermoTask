//
//  DateFormatter+Extensions.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import Foundation

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let ticketDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE dd MMM yyyy"
        return formatter
    }()

    static let ticketTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let ticketReminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - String Helpers

extension String {
    var strippingEmoji: String {
        filter { char in
            !char.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation })
        }
    }
}

// MARK: - Formatting Helpers

enum DateFormatting {
    static func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        } else {
            let startTime = DateFormatter.timeFormatter.string(from: event.startDate)
            let endTime = DateFormatter.timeFormatter.string(from: event.endDate)
            return "\(startTime) - \(endTime)"
        }
    }

    static func formatReminderTime(_ date: Date) -> String {
        DateFormatter.timeFormatter.string(from: date)
    }

    static func formatDateComponents(from date: Date) -> (day: String, month: String, year: String)
    {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)

        let day = "\(components.day ?? 1)"
        let month = DateFormatter.monthFormatter.string(from: date)
        let year = "\(components.year ?? 2025)"

        return (day, month, year)
    }
}
