//
//  PrintService.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 21/02/26.
//

import Combine
import Foundation

/// Thread-safe buffer for collecting process output from background callbacks.
nonisolated private final class OutputBuffer: Sendable {
    private nonisolated(unsafe) var _data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        _data.append(newData)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }
}

enum PrintState: Equatable {
    case idle
    case printing
    case finished
    case error(String)
}

@MainActor
class PrintService: ObservableObject {
    @Published var state: PrintState = .idle

    var isError: Bool {
        if case .error = state { return true }
        return false
    }

    private var process: Process?

    func printTicket(at url: URL) async {
        guard state != .printing else { return }

        guard let cliURL = Bundle.main.url(forResource: "niimblue-cli", withExtension: nil) else {
            state = .error("niimblue-cli not found in app bundle")
            return
        }

        state = .printing

        let process = Process()
        process.executableURL = cliURL
        process.arguments = [
            "print",
            url.path,
            "--address", "B1-H114122249",
        ]

        // Point NODE_PATH to bundled native modules so the compiled binary can find them
        var env = ProcessInfo.processInfo.environment
        if let resourceURL = Bundle.main.resourceURL {
            env["NODE_PATH"] = resourceURL.appendingPathComponent("node_modules").path
        }
        // Force sharp to use bundled libvips
        env["SHARP_IGNORE_GLOBAL_LIBVIPS"] = "1"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        self.process = process

        do {
            // Ensure executable permission
            let fm = FileManager.default
            if fm.isExecutableFile(atPath: cliURL.path) == false {
                let chmodTask = Process()
                chmodTask.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodTask.arguments = ["+x", cliURL.path]
                try chmodTask.run()
                chmodTask.waitUntilExit()
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Use a thread-safe buffer to drain pipe output continuously,
                // preventing deadlock when the CLI produces more output than the pipe buffer can hold.
                let outputBuffer = OutputBuffer()
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    outputBuffer.append(handle.availableData)
                }

                process.terminationHandler = { proc in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if proc.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let raw = String(data: outputBuffer.data, encoding: .utf8) ?? "Unknown error"
                        let lastLines = raw
                            .split(separator: "\n", omittingEmptySubsequences: false)
                            .suffix(5)
                            .joined(separator: "\n")
                        let output = lastLines.count > 500
                            ? String(lastLines.suffix(500))
                            : lastLines
                        continuation.resume(throwing: NSError(
                            domain: "PrintService",
                            code: Int(proc.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: output]
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
            state = .finished
        } catch {
            if (error as NSError).domain == "PrintService" {
                state = .error((error as NSError).localizedDescription)
            } else {
                state = .error(error.localizedDescription)
            }
        }

        self.process = nil
    }

    func cancelCurrentPrint() {
        process?.terminate()
        process = nil
        state = .idle
    }

    nonisolated static func cleanupTicketsDirectory() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ticketsDir = appSupport.appendingPathComponent("Tickets")

        guard let files = try? fm.contentsOfDirectory(at: ticketsDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            try? fm.removeItem(at: file)
        }
    }
}
