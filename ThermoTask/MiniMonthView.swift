//
//  MiniMonthView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import SwiftUI

struct MiniMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols: [String] = {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday first
        let symbols = cal.veryShortWeekdaySymbols
        let offset = 1  // Monday index in Sun-based array
        return Array(symbols[offset...] + symbols[..<offset])
    }()

    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
        _displayedMonth = State(initialValue: viewModel.selectedDate)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: dayColumns, spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: dayColumns, spacing: 2) {
                ForEach(Array(daysInMonthGrid(for: displayedMonth).enumerated()), id: \.offset) {
                    _, date in
                    DayCell(
                        date: date,
                        isSelected: date.map {
                            calendar.isDate($0, inSameDayAs: viewModel.selectedDate)
                        } ?? false,
                        isToday: date.map { calendar.isDateInToday($0) } ?? false
                    ) {
                        if let date { viewModel.goToDate(date) }
                    }
                }
            }
        }
        .padding(12)
        .onChange(of: viewModel.selectedDate) { _, newDate in
            let newMonth = calendar.dateComponents([.year, .month], from: newDate)
            let currentMonth = calendar.dateComponents([.year, .month], from: displayedMonth)
            if newMonth.year != currentMonth.year || newMonth.month != currentMonth.month {
                displayedMonth = newDate
            }
        }
    }

    private var monthTitle: String {
        DateFormatter.monthYearFormatter.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth)
        else { return }
        displayedMonth = newMonth
    }

    private func daysInMonthGrid(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
            let firstDayOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: monthInterval.start))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingPadding = (firstWeekday + 5) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingPadding)

        let range = calendar.range(of: .day, in: .month, for: date)!
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                cells.append(dayDate)
            }
        }

        while cells.count < 42 { cells.append(nil) }

        return cells
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date?
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if let date {
                let day = Calendar.current.component(.day, from: date)
                Button(action: onTap) {
                    Text("\(day)")
                        .font(
                            .system(size: 11, weight: isSelected || isToday ? .semibold : .regular)
                        )
                        .frame(width: 26, height: 26)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background {
                            if isSelected {
                                Circle().fill(Color.accentColor)
                            } else if isToday {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .overlay(
                                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 26, height: 26)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
