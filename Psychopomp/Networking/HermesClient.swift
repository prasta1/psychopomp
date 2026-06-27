import Foundation

/// A model entry from `GET /v1/models`.
struct HermesModelInfo: Identifiable, Decodable, Hashable {
    let id: String
    var owned_by: String?
}

struct HermesError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Thrown internally when the Runs API isn't available so the client can fall
/// back to `/v1/chat/completions`.
private struct TransportUnavailable: Error {}

// MARK: - Wire message types (OpenAI-compatible)

struct WirePart: Encodable {
    let type: String              // "text" | "image_url"
    var text: String?
    var image_url: ImageURL?
    struct ImageURL: Encodable { let url: String }
}

/// Content is a bare string for text-only messages, or an array of parts when an
/// image is attached (Hermes accepts inline `data:` image URLs).
enum WireContent: Encodable {
    case text(String)
    case parts([WirePart])

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s): try c.encode(s)
        case .parts(let p): try c.encode(p)
        }
    }
}

struct WireMessage: Encodable {
    let role: String
    let content: WireContent
}

/// Talks to a self-hosted hermes-agent OpenAI-compatible API server.
final class HermesClient {
    private let config: HermesConfig

    /// A session that never times out mid-stream.
    private let streamingSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 600
        cfg.timeoutIntervalForResource = 3600
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    init(config: HermesConfig) { self.config = config }

    private enum Transport { case runs, chat }

    // MARK: Discovery

    /// `GET /health` — returns true on any 2xx.
    func health() async throws -> Bool {
        let (_, response) = try await URLSession.shared.data(for: try request("/health", method: "GET"))
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    /// `GET /v1/models`.
    func listModels() async throws -> [HermesModelInfo] {
        let (data, response) = try await URLSession.shared.data(for: try request("/v1/models", method: "GET"))
        try Self.validate(response, data: data)
        struct ModelList: Decodable { let data: [HermesModelInfo] }
        return (try? JSONDecoder().decode(ModelList.self, from: data))?.data ?? []
    }

    // MARK: Streaming a turn

    /// Stream a turn. Tries the Runs API first (tool progress, stop, approvals);
    /// on 400/404/405/422/501 falls back to `/v1/chat/completions`.
    func stream(messages: [WireMessage], model: String, sessionKey: String)
        -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runStream(.runs, messages: messages, model: model, sessionKey: sessionKey) {
                        continuation.yield($0)
                    }
                    continuation.finish()
                } catch is TransportUnavailable {
                    do {
                        try await runStream(.chat, messages: messages, model: model, sessionKey: sessionKey) {
                            continuation.yield($0)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runStream(_ transport: Transport,
                           messages: [WireMessage],
                           model: String,
                           sessionKey: String,
                           yield: (StreamEvent) -> Void) async throws {
        let path = transport == .runs ? "/v1/runs" : "/v1/chat/completions"
        var body: [String: Any] = [
            "model": model,
            "messages": try encodeMessages(messages),
            "stream": true,
        ]
        if transport == .runs { body["store"] = true }

        let req = try request(path, method: "POST", json: body, sessionKey: sessionKey)
        let (bytes, response) = try await streamingSession.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw HermesError("No HTTP response") }

        // 400/422 mean the Runs API rejected the request format — fall back to chat/completions.
        if transport == .runs, [400, 404, 405, 422, 501].contains(http.statusCode) {
            throw TransportUnavailable()
        }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            let serverDetail = String(decoding: body, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(300)
            let detail = serverDetail.isEmpty
                ? "Check the base URL and API key."
                : String(serverDetail)
            throw HermesError("HTTP \(http.statusCode) from \(path): \(detail)")
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()

        // Runs API may answer the POST with a run object instead of a stream;
        // in that case open the dedicated events stream.
        if transport == .runs, !contentType.contains("event-stream") {
            var collected = Data()
            for try await byte in bytes { collected.append(byte) }
            let json = JSON(string: String(decoding: collected, as: UTF8.self))
            let runId = json?["id"].string ?? json?["run_id"].string ?? json?["run"]["id"].string
            guard let runId else { throw TransportUnavailable() }
            yield(.runId(runId))
            try await consumeEvents(runId: runId, sessionKey: sessionKey, yield: yield)
            return
        }

        try await consume(bytes: bytes, runId: "", yield: yield)
    }

    /// Open `GET /v1/runs/{id}/events` and stream it.
    private func consumeEvents(runId: String, sessionKey: String, yield: (StreamEvent) -> Void) async throws {
        let req = try request("/v1/runs/\(runId)/events", method: "GET", sessionKey: sessionKey)
        let (bytes, response) = try await streamingSession.bytes(for: req)
        try Self.validate(response, data: nil)
        try await consume(bytes: bytes, runId: runId, yield: yield)
    }

    private func consume(bytes: URLSession.AsyncBytes, runId: String, yield: (StreamEvent) -> Void) async throws {
        var currentRunId = runId
        for try await message in SSEParser.events(from: bytes) {
            for event in RunEventDecoder.decode(message, runId: currentRunId) {
                if case .runId(let id) = event { currentRunId = id }
                yield(event)
                if case .done = event { return }
            }
        }
    }

    // MARK: Control

    /// `POST /v1/runs/{id}/stop`.
    func stop(runId: String) async {
        guard !runId.isEmpty else { return }
        guard let req = try? request("/v1/runs/\(runId)/stop", method: "POST") else { return }
        _ = try? await URLSession.shared.data(for: req)
    }

    /// `POST /v1/runs/{id}/approval` — resolve an approval gate.
    func resolveApproval(runId: String, approvalId: String, approved: Bool) async {
        guard !runId.isEmpty else { return }
        let body: [String: Any] = [
            "approval_id": approvalId,
            "decision": approved ? "approve" : "deny",
            "approved": approved,
        ]
        if let req = try? request("/v1/runs/\(runId)/approval", method: "POST", json: body) {
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    // MARK: Request building

    private func request(_ path: String,
                         method: String,
                         json: [String: Any]? = nil,
                         sessionKey: String? = nil) throws -> URLRequest {
        guard let base = config.normalizedBaseURL else {
            throw HermesError("No base URL configured.")
        }
        guard let url = URL(string: base.absoluteString + path) else {
            throw HermesError("Invalid URL for \(path).")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let sessionKey, !sessionKey.isEmpty {
            req.setValue(sessionKey, forHTTPHeaderField: "X-Hermes-Session-Key")
        }
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return req
    }

    /// Encode `[WireMessage]` to plain `[[String: Any]]` for JSONSerialization.
    private func encodeMessages(_ messages: [WireMessage]) throws -> [Any] {
        let data = try JSONEncoder().encode(messages)
        return (try JSONSerialization.jsonObject(with: data)) as? [Any] ?? []
    }

    private static func validate(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw HermesError("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw HermesError("HTTP \(http.statusCode). Check the base URL and API key.")
        }
    }
}
