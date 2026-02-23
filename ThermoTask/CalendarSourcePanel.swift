//
//  CalendarSourcePanel.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import SwiftUI

struct CalendarSourcePanel: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.allEventCalendars.isEmpty {
                    calendarSection(
                        title: "Calendars",
                        groups: viewModel.eventCalendarsBySource,
                        enabledIds: viewModel.enabledCalendarIds,
                        toggle: viewModel.toggleCalendar
                    )
                }

                if !viewModel.allReminderLists.isEmpty {
                    calendarSection(
                        title: "Reminders",
                        groups: viewModel.reminderListsBySource,
                        enabledIds: viewModel.enabledReminderListIds,
                        toggle: viewModel.toggleReminderList
                    )
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 225, ideal: 225, max: 225)
    }

    private func calendarSection(
        title: String,
        groups: [(sourceName: String, calendars: [EKCalendar])],
        enabledIds: Set<String>,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(groups, id: \.sourceName) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                    ForEach(group.calendars, id: \.calendarIdentifier) { cal in
                        CheckboxRow(
                            color: Color(cgColor: cal.cgColor),
                            title: cal.title,
                            isEnabled: enabledIds.contains(cal.calendarIdentifier)
                        ) {
                            toggle(cal.calendarIdentifier)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - CheckboxRow

private struct CheckboxRow: View {
    let color: Color
    let title: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isEnabled ? color : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 1.5))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(isEnabled ? 1 : 0)
                    )
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
