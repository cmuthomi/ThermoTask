//
//  ReminderRowView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import SwiftUI

/// A view that displays a single reminder as a card
struct ReminderRowView: View {
    let reminder: EKReminder
    var titleWeight: Font.Weight = .semibold
    var compact: Bool = false
    var isSelected: Bool = false
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSelect: (() -> Void)?
    let onToggle: () -> Void

    private var cardColor: Color {
        if let cgColor = reminder.calendar.cgColor {
            return Color(cgColor: cgColor)
        }
        return Color.accentColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title ?? "Untitled Reminder")
                    .font(compact ? .body : .title3)
                    .fontWeight(titleWeight)
                    .strikethrough(reminder.isCompleted)

                if let dueDate = reminder.dueDateComponents?.date {
                    Text(DateFormatting.formatReminderTime(dueDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(20)
                }
            }

            Spacer()

            Button {
                onToggle()
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            Button { onEdit?() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { onDelete?() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
