import Foundation

/// A tiny read-only JSON value with chainable, never-throwing subscripts.
///
/// Used to read loosely-specified SSE payloads without committing to a rigid
/// Codable shape. Missing paths simply yield `.null`.
///
///     let j = JSON(string: payload)
///     j["choices"][0]["delta"]["content"].string   // String?
@dynamicMemberLookup
struct JSON {
    let raw: Any?

    init?(string: String) {
        guard let data = string.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        self.raw = obj
    }

    private init(raw: Any?) { self.raw = raw }

    static let null = JSON(raw: nil)

    subscript(key: String) -> JSON {
        JSON(raw: (raw as? [String: Any])?[key])
    }

    subscript(index: Int) -> JSON {
        guard let arr = raw as? [Any], arr.indices.contains(index) else { return .null }
        return JSON(raw: arr[index])
    }

    subscript(dynamicMember member: String) -> JSON {
        self[member]
    }

    var string: String? {
        if let s = raw as? String { return s }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    var int: Int? { (raw as? NSNumber)?.intValue ?? Int((raw as? String) ?? "") }
    var double: Double? { (raw as? NSNumber)?.doubleValue }
    var bool: Bool? { raw as? Bool }
    var array: [JSON]? { (raw as? [Any])?.map { JSON(raw: $0) } }
    var exists: Bool { raw != nil }
}
