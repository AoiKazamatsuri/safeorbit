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
}
@MainActor protocol AgentChatServing {
    func ask(_ question: String, language: String) async throws -> AgentResponse
}
@MainActor struct AgentChatAPI: AgentChatServing {
    let device: DemoDevice
    func ask(_ question: String, language: String) async throws -> AgentResponse {
        struct Body: Encodable { let question: String; let language: String; let allowTripHistory: Bool }
        let body = try JSONEncoder().encode(Body(question: question, language: language, allowTripHistory: true))
        do { return try await device.request("agent/chat", method: "POST", body: body) }
        catch let error as APIError where error.kind == .unauthorized {
            return try await device.request("agent/chat", method: "POST", body: body)
        }
    }
}
