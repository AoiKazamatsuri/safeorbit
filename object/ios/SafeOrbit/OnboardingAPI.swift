import Foundation
import Security

struct APIError: Error, LocalizedError {
    enum Kind { case unauthorized, unavailable, invalidCode, invalidInput, network, other }
    let kind: Kind
    var errorDescription: String? {
        switch kind {
        case .unauthorized: return "Session expired. Sign in again."
        case .unavailable: return "Service unavailable. Try again."
        case .invalidCode: return "Code expired or used. Ask for a new code."
        case .invalidInput: return "Check your details and try again."
        case .network: return "Check your connection and try again."
        case .other: return "Something went wrong. Try again."
        }
    }
}
struct OnboardingAPI {
    let baseURL: URL
    var session: URLSession = .shared
    func request<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil,
                                body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1").appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 15
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { if (error as? URLError)?.code == .cancelled { throw CancellationError() }; throw APIError(kind: .network) }
        guard let http = response as? HTTPURLResponse else { throw APIError(kind: .network) }
        guard (200..<300).contains(http.statusCode) else {
            let kind: APIError.Kind
            switch http.statusCode {
            case 401: kind = .unauthorized
            case 409, 410: kind = .invalidCode
            case 400, 422: kind = .invalidInput
            case 404, 501, 503: kind = .unavailable
            default: kind = .other
            }
            throw APIError(kind: kind)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: s) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            if let d = formatter.date(from: s) { return d }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid timestamp"))
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError(kind: .other) }
    }
    static func body(_ value: [String: String]) throws -> Data { try JSONEncoder().encode(value) }
}

struct SessionVaultError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Could not save your session. Try again." }
}

final class SessionVault {
    private let service: String
    init(service: String = "org.safeorbit.session") { self.service = service }
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service, kSecAttrAccount as String: "session"] }
    private struct StoredCredential: Codable { let token: String; let role: String }
    private func stored() -> StoredCredential? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }
    func load() -> String? { stored()?.token }
    func role() -> String? { stored()?.role }
    func save(_ token: String, role: String = "caregiver") throws {
        let data = try JSONEncoder().encode(StoredCredential(token: token, role: role))
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard update == errSecSuccess else { throw SessionVaultError(status: update) }
        } else if status != errSecSuccess { throw SessionVaultError(status: status) }
    }
    func clear() { SecItemDelete(query as CFDictionary) }
}
