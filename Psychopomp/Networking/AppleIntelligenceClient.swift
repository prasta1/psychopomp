import Foundation
import FoundationModels

/// On-device Apple Intelligence client. Wraps `SystemLanguageModel` and exposes
/// the same `StreamEvent`-based streaming interface as `HermesClient` so
/// `ChatViewModel` can drive both providers uniformly.
///
/// Each conversation gets its own `LanguageModelSession`, which maintains internal
/// context across turns within a single app session.
@available(iOS 26.0, *)
final class AppleIntelligenceClient {
    static let modelDisplayName = "Apple Intelligence"

    private var sessions: [UUID: LanguageModelSession] = [:]
    private let model = SystemLanguageModel.default

    var availability: SystemLanguageModel.Availability { model.availability }
    var isAvailable: Bool { model.availability == .available }

    /// Returns the persistent session for `id`, creating one on first access.
    func session(for id: UUID) -> LanguageModelSession {
        if let existing = sessions[id] { return existing }
        let session = LanguageModelSession()
        sessions[id] = session
        return session
    }

    /// Streams a response to `prompt`, emitting `.textDelta` / `.done` `StreamEvent`s.
    /// The session for `conversationId` accumulates context across calls automatically.
    func stream(conversationId: UUID, prompt: String) -> AsyncThrowingStream<StreamEvent, Error> {
        let session = session(for: conversationId)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let responseStream = session.streamResponse(to: prompt)
                    // Each Snapshot's `content` is the full accumulated String so far.
                    // Track the previously emitted length and emit only the new portion.
                    var previousLength = 0
                    for try await snapshot in responseStream {
                        let partial = snapshot.content
                        if partial.count > previousLength {
                            let delta = String(partial.dropFirst(previousLength))
                            continuation.yield(.textDelta(delta))
                            previousLength = partial.count
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
