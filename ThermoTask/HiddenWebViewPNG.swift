//
//  HiddenWebViewPNG.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 21/02/26.
//

import EventKit
import SwiftUI

// MARK: - TicketView

struct TicketView: View {
    let badge: String
    let title: String
    let calendarColor: Color
    let calendarName: String
    let dateString: String
    let timeString: String?
    let location: String?
    let priority: String?
    let notes: String?

    init(event: EKEvent) {
        self.badge = "EVENT"
        self.title = event.title ?? "Untitled Event"
        self.calendarColor = Color(cgColor: event.calendar.cgColor)
        self.calendarName = event.calendar.title

        self.dateString = DateFormatter.ticketDateFormatter.string(from: event.startDate)

        if event.isAllDay {
            self.timeString = "All day"
        } else {
            let fmt = DateFormatter.ticketTimeFormatter
            self.timeString = "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
        }

        self.location = event.location?.isEmpty == false ? event.location : nil
        self.priority = nil
        self.notes = event.notes?.isEmpty == false ? event.notes : nil
    }

    init(reminder: EKReminder, date: Date) {
        self.badge = "TODO"
        self.title = reminder.title ?? "Untitled Reminder"
        self.calendarColor = Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0, green: 0.478, blue: 1, alpha: 1))
        self.calendarName = reminder.calendar?.title ?? ""

        self.dateString = DateFormatter.ticketDateFormatter.string(from: date)

        if let dueDate = reminder.dueDateComponents?.date {
            self.timeString = DateFormatter.ticketReminderTimeFormatter.string(from: dueDate)
        } else {
            self.timeString = nil
        }

        self.location = nil
        
        switch reminder.priority {
            case 1: self.priority = "⚡⚡⚡"
            case 5: self.priority = "⚡⚡"
            case 9: self.priority = "⚡"
            default: self.priority = nil
        }

        self.notes = reminder.notes?.isEmpty == false ? reminder.notes : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Badge
            Text(badge)
                .font(.custom("Bungee-Regular", size: 60))
                .frame(maxWidth: .infinity, alignment: .center)
                .kerning(1.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 5)
            
            // Date field
            Text("\(dateString)")
                .font(.custom("Bungee-Regular", size: 26))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Upper Line
            Text("┏━━━━━━━━━━━━━━━━━━━━━━┓")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)
            
            // Title with emojis filtered out
            Text(title.strippingEmoji)
                .font(.custom("Bungee-Regular", size: 34))
                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Priority field (reminders only)
            if let priority {
                Text("\(priority)")
                    .font(.custom("NotoEmoji-Regular", size: 34))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }
            
            // Bottom Line
            Text("┗━━━━━━━━━━━━━━━━━━━━━━┛")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Time field
            if let timeString {
                fieldRow(icon: "⏰", text: timeString == "00:00" ? "⏳" : timeString)
                    .padding(.horizontal, 2)
            }

            // Location field (events only)
            if let location {
                fieldRow(icon: "📍", text: location)
                    .padding(.horizontal, 2)
            }

            // Notes block
            if let notes {
                Text(notes.strippingEmoji)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0, green: 0, blue: 0))
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    )
                    .padding(.top, 12)
                    .padding(.horizontal, 2)
            }
            
            // Bottom badges
            let logo = badge == "TODO" ? "👾" : "📅"
            HStack(spacing: 10) {
                // Debug badge
                HStack(spacing: 6) {
                    Text(logo)
                        .font(.custom("NotoEmoji-Regular", size: 24))
                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1.25)
                )

                // Calendar group
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 16, height: 16)
                    Text(calendarName.strippingEmoji)
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1.25)
                )
            }
            .padding(.top, 20)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 0)
        .padding(.top, 24)
        .padding(.bottom, 2)
        .frame(width: 384, alignment: .leading)
        .background(Color.white)
    }
    
    private func mixedFontText(_ string: String, baseFont: Font, emojiSize: CGFloat) -> Text {
        var attributedString = AttributedString()

        for char in string {
            var attrChar = AttributedString(String(char))
            if char.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
                attrChar.font = .custom("NotoEmoji-Regular", size: emojiSize)
            } else {
                attrChar.font = baseFont
            }
            attributedString.append(attrChar)
        }
        return Text(attributedString)
    }
    
    private func fieldRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.custom("NotoEmoji-Regular", size: 20))
            
            mixedFontText(text, baseFont: .system(size: 22), emojiSize: 20)
                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.bottom, 10)
    }
}

// MARK: - TicketRenderer

enum TicketRenderer {
    @MainActor
    static func pngData(for view: some View, width: CGFloat) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)

        guard let nsImage = renderer.nsImage else {
            print("TicketRenderer: failed to create nsImage")
            return nil
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("TicketRenderer: failed to convert to PNG")
            return nil
        }

        bitmap.size = NSSize(
            width:  CGFloat(bitmap.pixelsWide) * 72.0 / 203.0,
            height: CGFloat(bitmap.pixelsHigh) * 72.0 / 203.0
        )

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            print("TicketRenderer: failed to convert to PNG")
            return nil
        }

        return data
    }
}
