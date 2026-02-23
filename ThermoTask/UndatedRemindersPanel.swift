//
//  UndatedRemindersPanel.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import SwiftUI

struct UndatedRemindersPanel: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @State private var collapsedGroups: Set<String> = []
    @State private var hasOpenedOnce = false
    @State private var targetedGroup: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Undated Reminders")
                .font(.custom("Bungee-Regular", size: 13))
                .foregroundStyle(.secondary)
                .padding()

            if viewModel.allReminderLists.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Undated Reminders")
                            .font(.custom("Bungee-Regular", size: 22))
                    } icon: {
                        Image(systemName: "checklist")
                    }
                } description: {
                    Text("All your reminders have a due date.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.undatedRemindersByList, id: \.title) { group in
                            reminderGroup(group)
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: isPresented) { _, isShowing in
            if isShowing && !hasOpenedOnce {
                collapsedGroups = Set(viewModel.undatedRemindersByList.map { $0.title })
                hasOpenedOnce = true
            }
        }
    }

    private func reminderGroup(
        _ group: (title: String, color: Color, calendar: EKCalendar, reminders: [EKReminder])
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if collapsedGroups.contains(group.title) {
                    collapsedGroups.remove(group.title)
                } else {
                    collapsedGroups.insert(group.title)
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(group.color)
                        .frame(width: 10, height: 10)
                    Text(group.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(
                        systemName: collapsedGroups.contains(group.title)
                            ? "chevron.right" : "chevron.down"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if !collapsedGroups.contains(group.title) {
                ForEach(group.reminders, id: \.calendarItemIdentifier) { reminder in
                    ReminderRowView(
                        reminder: reminder,
                        titleWeight: .regular,
                        compact: true,
                        isSelected: viewModel.isSelected(reminder.calendarItemIdentifier),
                        onSelect: {
                            viewModel.toggleSelection(reminder.calendarItemIdentifier)
                        },
                        onToggle: {
                            viewModel.toggleReminder(reminder)
                        }
                    )
                    .draggable(reminder.calendarItemIdentifier)
                }
            }
        }
        .padding(8)
        .dropDestination(for: String.self) { identifiers, _ in
            guard let id = identifiers.first else { return false }
            let idsToUnassign = viewModel.selectedItems.contains(id)
                ? Array(viewModel.selectedItems)
                : [id]
            viewModel.unassignDates(
                fromReminderWithIdentifiers: idsToUnassign, targetCalendar: group.calendar)
            return true
        } isTargeted: { targeted in
            targetedGroup = targeted ? group.title : nil
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    targetedGroup == group.title
                        ? Color.accentColor.opacity(0.1) : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            targetedGroup == group.title
                                ? Color.accentColor : Color.clear,
                            lineWidth: 1.5)
                )
        )
    }
}
