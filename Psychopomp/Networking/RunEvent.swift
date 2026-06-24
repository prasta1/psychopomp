import Foundation

/// A semantic event distilled from the SSE stream, regardless of which Hermes
/// vocabulary produced it (Runs `response.*`, OpenAI `chat.completion.chunk`, or
/// the custom `hermes.tool.progress`).
enum StreamEvent {
    case runId(String)
    case textDelta(String)
    case toolStarted(id: String, name: String, detail: String)
    case toolFinished(id: String, success: Bool)
    case approvalRequired(ApprovalRequest)
    case completed
    case failed(String)
    case done   // [DONE] sentinel
}

/// An approval gate raised by the agent before it runs a sensitive tool.
struct ApprovalRequest: Identifiable, Equatable {
    let id: String          // approval / call id to echo back to /approval
    let runId: String
    let toolName: String
    let detail: String
}

/// Tolerant translation of a raw `SSEMessage` into zero or more `StreamEvent`s.
///
/// The exact Runs API event schema is not exhaustively documented, so this reads
/// defensively: it accepts several field spellings, ignores unknown events, and
/// falls back gracefully. Validate field names against the running server and
/// extend the `switch` as needed.
enum RunEventDecoder {
    static func decode(_ message: SSEMessage, runId: String) -> [StreamEvent] {
        let payload = message.data.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload == "[DONE]" { return [.done] }
        guard let json = JSON(string: payload) else { return [] }

        // Prefer the explicit SSE event name; fall back to a `type`/`object` field.
        let type = message.event ?? json["type"].string ?? json["object"].string ?? ""

        switch type {
        // ---- Runs / Responses API ----
        case "response.created", "run.created":
            if let id = json["response"]["id"].string ?? json["id"].string { return [.runId(id)] }
            return []

        case "response.output_text.delta", "response.text.delta", "output_text.delta":
            if let delta = json["delta"].string ?? json["text"].string { return [.textDelta(delta)] }
            return []

        case "response.completed", "response.done", "run.completed":
            return [.completed]

        case "response.failed", "run.failed", "error":
            let msg = json["error"]["message"].string ?? json["message"].string ?? "Run failed"
            return [.failed(msg)]

        case "response.function_call.created", "function_call", "run.tool.started":
            return [toolStarted(json, fallbackRunId: runId)]

        case "response.function_call.completed", "function_call_output", "run.tool.completed":
            let id = json["call_id"].string ?? json["id"].string ?? UUID().uuidString
            let ok = (json["status"].string ?? "succeeded") != "failed"
            return [.toolFinished(id: id, success: ok)]

        case "run.approval.required", "response.approval.required", "approval.required":
            return [approval(json, runId: runId)]

        // ---- Custom Hermes tool progress ----
        case "hermes.tool.progress":
            return [hermesToolProgress(json, fallbackRunId: runId)]

        // ---- OpenAI chat.completion.chunk (fallback transport) ----
        case "chat.completion.chunk", "":
            return chatChunk(json)

        default:
            // Unknown event: try to salvage a text delta or a tool-progress shape.
            if let delta = json["choices"][0]["delta"]["content"].string ?? json["delta"].string {
                return [.textDelta(delta)]
            }
            if json["tool"].string != nil || json["tool_name"].string != nil {
                return [hermesToolProgress(json, fallbackRunId: runId)]
            }
            return []
        }
    }

    private static func chatChunk(_ json: JSON) -> [StreamEvent] {
        var out: [StreamEvent] = []
        let choice = json["choices"][0]
        if let content = choice["delta"]["content"].string, !content.isEmpty {
            out.append(.textDelta(content))
        }
        if let finish = choice["finish_reason"].string, !finish.isEmpty {
            out.append(.completed)
        }
        return out
    }

    private static func toolStarted(_ json: JSON, fallbackRunId: String) -> StreamEvent {
        let id = json["call_id"].string ?? json["id"].string ?? UUID().uuidString
        let name = json["name"].string ?? json["tool"].string ?? json["function"]["name"].string ?? "tool"
        let detail = json["arguments"].string ?? json["detail"].string ?? json["function"]["arguments"].string ?? ""
        return .toolStarted(id: id, name: name, detail: detail)
    }

    private static func hermesToolProgress(_ json: JSON, fallbackRunId: String) -> StreamEvent {
        let id = json["call_id"].string ?? json["id"].string ?? UUID().uuidString
        let name = json["tool"].string ?? json["tool_name"].string ?? json["name"].string ?? "tool"
        let detail = json["detail"].string ?? json["message"].string ?? json["arguments"].string ?? ""
        let phase = json["status"].string ?? json["phase"].string ?? "running"
        switch phase {
        case "succeeded", "completed", "done", "success":
            return .toolFinished(id: id, success: true)
        case "failed", "error":
            return .toolFinished(id: id, success: false)
        default:
            return .toolStarted(id: id, name: name, detail: detail)
        }
    }

    private static func approval(_ json: JSON, runId: String) -> StreamEvent {
        let id = json["approval_id"].string ?? json["call_id"].string ?? json["id"].string ?? UUID().uuidString
        let tool = json["tool"].string ?? json["name"].string ?? json["tool_name"].string ?? "tool"
        let detail = json["detail"].string ?? json["arguments"].string ?? json["message"].string ?? ""
        return .approvalRequired(ApprovalRequest(id: id, runId: runId, toolName: tool, detail: detail))
    }
}
