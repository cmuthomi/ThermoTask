//
//  PrintQueueView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 21/02/26.
//

import SwiftUI

struct PrintQueueView: View {
    let ticketURLs: [URL]
    @StateObject private var printService = PrintService()
    @State private var currentIndex = 0
    @State private var phase: QueuePhase = .ready
    @Environment(\.dismiss) private var dismiss

    enum QueuePhase {
        case ready
        case printing
        case waitingForNext
        case done
        case cancelled
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Print Queue")
                .font(.headline)

            if !ticketURLs.isEmpty {
                ticketPreview
            }

            Text("Ticket \(currentIndex + 1) of \(ticketURLs.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusContent

            actionButtons
        }
        .padding(24)
        .frame(minWidth: 340, idealWidth: 380, minHeight: 300)
        .onChange(of: printService.state) { _, newState in
            handleStateChange(newState)
        }
    }

    // MARK: - Ticket Preview

    @ViewBuilder
    private var ticketPreview: some View {
        if currentIndex < ticketURLs.count,
           let nsImage = NSImage(contentsOf: ticketURLs[currentIndex]) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
        }
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        switch phase {
        case .ready:
            Text("Ready to print")
                .foregroundStyle(.secondary)
        case .printing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Printing...")
            }
        case .waitingForNext:
            Text("Cut the paper, then tap Print Next")
                .foregroundStyle(.orange)
                .fontWeight(.medium)
        case .done:
            Label("All done!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .fontWeight(.medium)
        case .cancelled:
            EmptyView()
        }

        if case .error(let message) = printService.state {
            Text(message)
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(3)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch phase {
        case .ready:
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    cancelAndDismiss()
                }
                Button(printService.isError ? "Retry" : "Print") {
                    printService.state = .idle
                    startPrint()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        case .printing:
            Button("Cancel", role: .destructive) {
                printService.cancelCurrentPrint()
                cancelAndDismiss()
            }
        case .waitingForNext:
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    cancelAndDismiss()
                }
                Button("Print Next") {
                    startPrint()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        case .done:
            Button("Close") {
                PrintService.cleanupTicketsDirectory()
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
        case .cancelled:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func startPrint() {
        guard currentIndex < ticketURLs.count else { return }
        phase = .printing
        Task {
            await printService.printTicket(at: ticketURLs[currentIndex])
        }
    }

    private func handleStateChange(_ newState: PrintState) {
        switch newState {
        case .finished:
            if currentIndex + 1 < ticketURLs.count {
                currentIndex += 1
                phase = .waitingForNext
            } else {
                phase = .done
            }
        case .error:
            phase = .ready
        default:
            break
        }
    }

    private func cancelAndDismiss() {
        phase = .cancelled
        printService.cancelCurrentPrint()
        PrintService.cleanupTicketsDirectory()
        dismiss()
    }
}
