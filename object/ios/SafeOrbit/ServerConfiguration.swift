import Foundation

enum ServerConfiguration {
    static func validatedURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static var baseURL: URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SafeOrbitServerURL") as? String,
              let url = validatedURL(value) else {
            preconditionFailure("Invalid SafeOrbitServerURL build configuration")
        }
        return url
    }
}
