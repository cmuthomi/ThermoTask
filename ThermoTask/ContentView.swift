//
//  ContentView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import AppKit
import EventKit
import SwiftUI

enum EditingItem: Identifiable {
    case event(EKEvent)
    case reminder(EKReminder)
    var id: String {
        switch self {
        case .event(let e): e.eventIdentifier
        case .reminder(let r): r.calendarItemIdentifier
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var showInspector = false
    @State private var isDropTarget = false
    @State private var showNewItem = false
    @State private var isGeneratingTickets = false
    @State private var editingItem: EditingItem? = nil
    @State private var showPrintQueue = false
    @State private var ticketURLs: [URL] = []

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: CalendarViewModel())
    }

    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var editSheetBinding: Binding<Bool> {
        Binding(get: { editingItem != nil }, set: { if !$0 { editingItem = nil } })
    }

    var body: some View {
        NavigationSplitView {
            CalendarSourcePanel(viewModel: viewModel)
            Divider()
            MiniMonthView(viewModel: viewModel)
        } detail: {
            detailContent
        }
        .inspector(isPresented: $showInspector) {
            UndatedRemindersPanel(viewModel: viewModel, isPresented: $showInspector)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 400)
        }
        .sheet(isPresented: $showNewItem) {
            NewItemView(viewModel: viewModel, isPresented: $showNewItem)
                .frame(minWidth: 360, idealWidth: 400, maxWidth: 500, minHeight: 560)
        }
        .sheet(item: $editingItem) { item in
            Group {
                switch item {
                case .event(let event):
                    NewItemView(viewModel: viewModel, isPresented: editSheetBinding, editingEvent: event)
                case .reminder(let reminder):
                    NewItemView(viewModel: viewModel, isPresented: editSheetBinding, editingReminder: reminder)
                }
            }
            .frame(minWidth: 360, idealWidth: 400, maxWidth: 500, minHeight: 560)
        }
        .sheet(isPresented: $showPrintQueue) {
            PrintQueueView(ticketURLs: ticketURLs)
        }
        .toolbar {
            
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.goToPreviousDay()
                } label: {
                    Image(systemName: "chevron.backward")
                        .fontWeight(.regular)
                }
            }
            
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.goToNextDay()
                } label: {
                    Image(systemName: "chevron.forward")
                        .fontWeight(.regular)
                }
            }

            ToolbarItem(placement: .automatic) {
                Button("Today") {
                    viewModel.goToToday()
                }
                .disabled(viewModel.isToday)
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showNewItem = true
                } label: {
                    Label("New Item", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await generateTickets() }
                } label: {
                    Label("Generate Tickets", systemImage: "printer.dotmatrix")
                }
                .disabled(viewModel.selectedItems.isEmpty || isGeneratingTickets)
            }

            ToolbarItem(placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
            }
        }
        .navigationTitle("􀦜  ThermoTask")
        .task {
            await viewModel.requestAccess()
            await viewModel.fetchTodaysData()
        }
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        ScrollView(.vertical) {
            let components = DateFormatting.formatDateComponents(from: viewModel.selectedDate)
            Text("\(components.day) \(components.month) \(components.year)")
                .font(.custom("Bungee-Regular", size: 34))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.top, 21)
                .padding(.bottom, 6)
            Divider()
            Group {
                if viewModel.hasNoItems {
                    ContentUnavailableView {
                        Label {
                            Text("No Events or Reminders")
                                .font(.custom("Bungee-Regular", size: 22))
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    } description: {
                        Text(
                            viewModel.isToday
                                ? "Nothing scheduled for today."
                                : "Nothing scheduled for this date."
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    calendarListView
                }
            }
            .dropDestination(for: String.self) { identifiers, _ in
                guard let id = identifiers.first else { return false }
                let idsToAssign = viewModel.selectedItems.contains(id)
                    ? Array(viewModel.selectedItems)
                    : [id]
                viewModel.assignDates(toReminderWithIdentifiers: idsToAssign)
                return true
            } isTargeted: { targeted in
                isDropTarget = targeted
            }
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .background(
                            Color.accentColor.opacity(0.08)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                }
            }
        }
        .padding(.bottom, 0)
        .padding(.horizontal, 8)
        .alert(
            "Delete \(viewModel.selectedItems.count == 1 ? "Item" : "\(viewModel.selectedItems.count) Items")?",
            isPresented: $viewModel.showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) { viewModel.deleteSelectedItems() }
                .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Calendar List

    private var calendarListView: some View {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.displayedEvents.isEmpty {
                    Text("Events")
                        .font(.custom("Bungee-Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(viewModel.displayedEvents, id: \.eventIdentifier) { event in
                        EventRowView(
                            event: event,
                            isSelected: viewModel.isSelected(event.eventIdentifier),
                            onEdit: {
                                editingItem = .event(event)
                            },
                            onDelete: {
                                viewModel.selectedItems = [event.eventIdentifier]
                                viewModel.showDeleteConfirmation = true
                            }
                        ) {
                            handleSelection(event.eventIdentifier)
                        }
                    }
                    if !viewModel.displayedReminders.isEmpty{
                        Divider()
                    }
                }

                if !viewModel.displayedReminders.isEmpty {
                    Text("Reminders")
                        .font(.custom("Bungee-Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, viewModel.displayedEvents.isEmpty ? 0 : 8)

                    ForEach(viewModel.displayedReminders, id: \.calendarItemIdentifier) {
                        reminder in
                        ReminderRowView(
                            reminder: reminder,
                            isSelected: viewModel.isSelected(reminder.calendarItemIdentifier),
                            onEdit: {
                                editingItem = .reminder(reminder)
                            },
                            onDelete: {
                                viewModel.selectedItems = [reminder.calendarItemIdentifier]
                                viewModel.showDeleteConfirmation = true
                            },
                            onSelect: {
                                handleSelection(reminder.calendarItemIdentifier)
                            },
                            onToggle: {
                                viewModel.toggleReminder(reminder)
                            }
                        )
                        .draggable(reminder.calendarItemIdentifier)
                    }
                }

                Button("Select All") { viewModel.selectAll() }
                    .keyboardShortcut("a", modifiers: .command)
                    .frame(width: 0, height: 0)
                    .hidden()

                Button("Deselect All") { viewModel.clearSelection() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .frame(width: 0, height: 0)
                    .hidden()
                    .disabled(viewModel.selectedItems.isEmpty)

                Button("Delete") { viewModel.showDeleteConfirmation = true }
                    .keyboardShortcut(.delete, modifiers: [])
                    .frame(width: 0, height: 0)
                    .hidden()
                    .disabled(viewModel.selectedItems.isEmpty)

                Button("Delete via Return") { viewModel.showDeleteConfirmation = true }
                    .keyboardShortcut(.return, modifiers: [])
                    .frame(width: 0, height: 0)
                    .hidden()
                    .disabled(viewModel.selectedItems.isEmpty)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.clearSelection()
        }
    }
    // MARK: - Selection

    private func handleSelection(_ identifier: String) {
        if NSEvent.modifierFlags.contains(.command) {
            viewModel.toggleSelection(identifier)
        } else {
            viewModel.clearSelection()
            viewModel.toggleSelection(identifier)
        }
    }

    // MARK: - Ticket Generation

    private func renderTicket(name: String, index: Int, ticketsDir: URL, view: some View) -> URL? {
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .prefix(50)
        let outputURL = ticketsDir.appendingPathComponent("ticket-\(index)-\(safeName).png")
        guard let data = TicketRenderer.pngData(for: view, width: 384) else { return nil }
        do {
            try data.write(to: outputURL)
            return outputURL
        } catch {
            print("Failed to write ticket for \(safeName): \(error)")
            return nil
        }
    }

    private func generateTickets() async {
        isGeneratingTickets = true
        defer { isGeneratingTickets = false }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ticketsDir = appSupport.appendingPathComponent("Tickets")
        try? fm.createDirectory(at: ticketsDir, withIntermediateDirectories: true)

        var generatedURLs: [URL] = []
        var index = 0

        for event in viewModel.selectedEvents {
            if let url = renderTicket(
                name: event.title ?? "event",
                index: index,
                ticketsDir: ticketsDir,
                view: TicketView(event: event)
            ) {
                generatedURLs.append(url)
            }
            index += 1
        }

        for reminder in viewModel.selectedReminders {
            if let url = renderTicket(
                name: reminder.title ?? "reminder",
                index: index,
                ticketsDir: ticketsDir,
                view: TicketView(reminder: reminder, date: viewModel.selectedDate)
            ) {
                generatedURLs.append(url)
            }
            index += 1
        }

        viewModel.clearSelection()

        if !generatedURLs.isEmpty {
            ticketURLs = generatedURLs
            showPrintQueue = true
        }
    }
}

