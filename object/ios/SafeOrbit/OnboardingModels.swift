import Foundation

struct ElderProfile: Codable, Equatable {
    var id: String?
    var name = ""
    var callName = ""
    var phone = ""
    var timezone = TimeZone.current.identifier
    var photo: String?
    var bound = false
    enum CodingKeys: String, CodingKey { case id, name, callName, phone, timezone, photo, bound }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        callName = try c.decode(String.self, forKey: .callName)
        phone = try c.decode(String.self, forKey: .phone)
        timezone = try c.decode(String.self, forKey: .timezone)
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
        bound = try c.decodeIfPresent(Bool.self, forKey: .bound) ?? false
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 &&
        PhoneNumber.isValid(phone) && TimeZone(identifier: timezone) != nil
    }
}
enum PhoneNumber {
    static func normalized(_ value: String) -> String { value.filter { !" ()-\n\t".contains($0) } }
    static func isValid(_ value: String) -> Bool {
        normalized(value).range(of: "^\\+[1-9][0-9]{6,14}$", options: .regularExpression) != nil
    }
}
struct AuthChallenge: Codable { let id: String; let nonce: String }
struct Caregiver: Codable { let id: String; var phone: String? }
struct AppSession: Codable {
    let token: String?
    let role: String
    let caregiver: Caregiver?
    var elder: ElderProfile?
}
struct BindingCode: Codable {
    let token: String
    let expiresAt: Date
    var payload: String { "safeorbit://bind?token=\(token)" }
}
enum BindingPayload {
    static func token(from value: String) -> String? {
        guard let c = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              c.scheme == "safeorbit", c.host == "bind", c.path.isEmpty, c.user == nil,
              c.password == nil, c.port == nil, c.fragment == nil,
              let items = c.queryItems, items.count == 1, items[0].name == "token",
              let token = items[0].value,
              token.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else { return nil }
        return token
    }
}

struct PhoneCountry: Equatable, Identifiable {
    let name: String
    let code: String
    var id: String { code }
    static let choices = [
        PhoneCountry(name: "China", code: "+86"),
        PhoneCountry(name: "Hong Kong", code: "+852"),
        PhoneCountry(name: "Macau", code: "+853"),
        PhoneCountry(name: "Taiwan", code: "+886"),
        PhoneCountry(name: "United States", code: "+1"),
        PhoneCountry(name: "United Kingdom", code: "+44"),
        PhoneCountry(name: "Japan", code: "+81"),
        PhoneCountry(name: "Singapore", code: "+65"),
        PhoneCountry(name: "Australia", code: "+61")
    ]
    // Calling prefixes allow existing numbers outside the picker to round-trip.
    static let otherCodes = "7 20 27 30 31 32 33 34 36 39 40 41 43 45 46 47 48 49 51 52 53 54 55 56 57 58 60 62 63 64 66 90 91 92 93 94 95 98 211 212 213 216 218 220 221 222 223 224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255 256 257 258 260 261 262 263 264 265 266 267 268 269 290 291 297 298 299 350 351 352 353 354 355 356 357 358 359 370 371 372 373 374 375 376 377 378 380 381 382 383 385 386 387 389 420 421 423 500 501 502 503 504 505 506 507 508 509 590 591 592 593 594 595 596 597 598 599 670 672 673 674 675 676 677 678 679 680 681 682 683 685 686 687 688 689 690 691 692 800 808 850 855 856 870 878 880 881 882 883 888 960 961 962 963 964 965 966 967 968 970 971 972 973 974 975 976 977 979 992 993 994 995 996 998".split(separator: " ").map { "+" + $0 }
}
struct PhoneEntry: Equatable {
    var country = PhoneCountry.choices[0]
    var digits = ""
    init(_ fullNumber: String = "") {
        let normalized = PhoneNumber.normalized(fullNumber)
        let codes = PhoneCountry.choices.map(\.code) + PhoneCountry.otherCodes
        if normalized.hasPrefix("+"), let code = codes.sorted(by: { $0.count > $1.count }).first(where: { normalized.hasPrefix($0) }) {
            country = PhoneCountry.choices.first(where: { $0.code == code }) ?? PhoneCountry(name: "Current region", code: code)
            digits = Self.filtered(String(normalized.dropFirst(code.count)))
        } else {
            digits = Self.filtered(normalized)
        }
    }
    static func filtered(_ input: String) -> String { input.filter { $0 >= "0" && $0 <= "9" } }
    var fullNumber: String { digits.isEmpty ? "" : country.code + digits }
    var showsError: Bool { !digits.isEmpty && !PhoneNumber.isValid(fullNumber) }
}

enum EmailAddress {
    static func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func isValid(_ value: String) -> Bool {
        let value = normalized(value)
        return value.count <= 254 && value.range(of: #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#, options: .regularExpression) != nil
    }
}
struct GoogleChallenge: Decodable {
    let authorizationURL: String
    let state: String
    var validatedURL: URL? {
        guard !state.isEmpty, let parts = URLComponents(string: authorizationURL),
              parts.scheme == "https", parts.host == "accounts.google.com",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              let items = parts.queryItems, items.filter({ $0.name == "state" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == state else { return nil }
        return parts.url
    }
    static func callbackCode(_ url: URL, state: String) -> String? {
        guard !state.isEmpty, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "safeorbit", parts.host == "oauth", parts.path.isEmpty,
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              let items = parts.queryItems,
              items.filter({ $0.name == "state" }).count == 1,
              items.filter({ $0.name == "code" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else { return nil }
        return code
    }
}
