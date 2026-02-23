//
//  CalendarViewModel+Navigation.swift
//  ThermoTask
//

import Foundation

extension CalendarViewModel {

    // MARK: - Date Navigation

    func navigateTo(_ date: Date) {
        selectedDate = date
        selectedItems.removeAll()
        currentFetchTask?.cancel()
        currentFetchTask = Task { await fetchTodaysData() }
    }

    func goToPreviousDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)
        else { return }
        navigateTo(newDate)
    }

    func goToNextDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else {
            return
        }
        navigateTo(newDate)
    }

    func goToToday() {
        navigateTo(Date())
    }

    func goToDate(_ date: Date) {
        navigateTo(date)
    }
}
