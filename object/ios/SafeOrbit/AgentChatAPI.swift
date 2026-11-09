import Foundation

struct AgentCitation: Codable, Equatable, Sendable {
    let kind: String
    let id: String
    let label: String
    let date: String?
    let startDate: String?
    let endDate: String?
}
struct AgentResponse: Codable, Sendable {
    let outcome: String
    let paragraphs: [String]
    let citations: [AgentCitation]
    var localRequests: [String]? = nil
    var recordContext: [AgentRecordQuery]? = nil
    var retryable: Bool? = nil
}

struct AgentHistoryEntry: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    let role: Role
    let text: String
}

struct AgentRecordQuery: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case current, events, trip, compare, riskCount, safeZones, activity }
    enum Level: String, Codable, Sendable { case high, warning }
    let kind: Kind
    var id: String? = nil
    var month: String? = nil
    var from: String? = nil
    var to: String? = nil
    var level: Level? = nil
    var latest: Bool? = nil
}

struct AgentQuestion: Encodable, Sendable {
    let question: String
    let language: String
    let allowTripHistory: Bool
    var history: [AgentHistoryEntry]? = nil
    var recordContext: [AgentRecordQuery]? = nil
}

@MainActor protocol AgentChatServing {
    func ask(_ question: AgentQuestion) async throws -> AgentResponse
}
@MainActor struct AgentChatAPI: AgentChatServing {
    let device: DemoDevice
    func ask(_ question: AgentQuestion) async throws -> AgentResponse {
        let body = try JSONEncoder().encode(question)
        do { return try await device.request("agent/chat", method: "POST", body: body) }
        catch let error as APIError where error.kind == .unauthorized {
            return try await device.request("agent/chat", method: "POST", body: body)
        }
    }
}

/// Applies only to text sent off-device. The original question stays in the local transcript.
struct AgentPrivacyFilter {
    private static let patterns: [NSRegularExpression] = [
        #"\b(?:https?://|www\.|mailto:|tel:|safeorbit://)[^\s<>]+"#,
        #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        #"\b[A-Z0-9-]+\.(?:com|cn|org|net|io|dev|edu|gov)\b[^\s<>,，。]*"#,
        #"(?<!\d)(?:\+\s*\d(?:[ .()\-]*\d){6,14}|(?:\(\d{2,4}\)|\d{2,4})[ .\-]\d{3,4}[ .\-]\d{4}|\d{7,15})(?!\d)"#,
        #"[-+]?\d{1,3}\.\d{2,}\s*[,，/;； ]\s*[-+]?\d{1,3}\.\d{2,}|[-+]?\d{1,3}\.\d{4,}"#,
        #"[\p{Han}]{2,}(?:街|路|巷)\s*\d+\s*号"#
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    private static let addressDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
    private let knownValues: [NSRegularExpression]

    init(names: [String], otherValues: [String]) {
        // Names may appear as full names or as an individual word. Names in Chinese can
        // appear next to other Chinese words without intervening whitespace.
        let components = names.flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
        let values = Set((names + components + otherValues).map {
            Self.normalize($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })
        knownValues = values.sorted { $0.count > $1.count }.compactMap { value in
            let escaped = NSRegularExpression.escapedPattern(for: value)
            let pattern = value.first?.isASCII == true && value.last?.isASCII == true
                ? "(?<![A-Za-z0-9_])" + escaped + "(?![A-Za-z0-9_])" : escaped
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }
    }

    func redact(_ text: String) -> String {
        let text = Self.normalize(text)
        let range = NSRange(text.startIndex..., in: text)
        let expressions = Self.patterns + knownValues
        let matches = expressions.flatMap { $0.matches(in: text, range: range) }
            + (Self.addressDetector?.matches(in: text, range: range) ?? [])
        let ordered = matches.map(\.range).sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        for match in ordered {
            if let last = merged.last, match.location <= NSMaxRange(last) {
                merged[merged.count - 1] = NSUnionRange(last, match)
            } else {
                merged.append(match)
            }
        }
        let output = NSMutableString(string: text)
        for match in merged.reversed() { output.replaceCharacters(in: match, with: "□") }
        return output as String
    }

    private static func normalize(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.replacingOccurrences(of: "[\\u200B-\\u200D\\u2060\\uFEFF]",
                                                                            with: "", options: .regularExpression)
    }
}
