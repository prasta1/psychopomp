import Foundation

/// A single Server-Sent Event: an optional `event:` name plus the concatenated
/// `data:` payload lines.
struct SSEMessage {
    var event: String?
    var data: String
}

/// Parses a byte stream of `text/event-stream` into discrete `SSEMessage`s.
///
/// Handles multi-line `data:` fields, `event:` names, comments (`:`), and both
/// `\n\n` and `\r\n\r\n` event terminators. The terminal `data: [DONE]` sentinel
/// is forwarded as-is so callers can detect end-of-stream.
enum SSEParser {
    static func events(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEMessage, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var eventName: String?
                var dataLines: [String] = []

                func flush() {
                    guard !dataLines.isEmpty else { eventName = nil; return }
                    let data = dataLines.joined(separator: "\n")
                    continuation.yield(SSEMessage(event: eventName, data: data))
                    eventName = nil
                    dataLines.removeAll(keepingCapacity: true)
                }

                do {
                    for try await rawLine in bytes.lines {
                        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

                        if line.isEmpty {            // blank line == dispatch event
                            flush()
                            continue
                        }
                        if line.hasPrefix(":") { continue } // comment / heartbeat

                        if let colon = line.firstIndex(of: ":") {
                            let field = String(line[..<colon])
                            var value = String(line[line.index(after: colon)...])
                            if value.hasPrefix(" ") { value.removeFirst() }
                            switch field {
                            case "event": eventName = value
                            case "data": dataLines.append(value)
                            default: break          // id, retry — ignored
                            }
                        } else {
                            // field with no value
                            if line == "data" { dataLines.append("") }
                        }
                    }
                    flush()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
