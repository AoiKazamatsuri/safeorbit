import SwiftUI

struct AgentMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let fromCaregiver: Bool
    let text: String
    let createdAt: Date
    var citations: [AgentCitation]? = nil
    var failed: Bool? = nil
    var generalExchange: [AgentHistoryEntry]? = nil
    var recordContext: [AgentRecordQuery]? = nil
    var localRequests: [AgentLocalRequest]? = nil
    var language: String? = nil
}

struct AgentConversation: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [AgentMessage]
}

enum AgentDestination: String, Identifiable {
    case locationMap, safeZonesMap, tripRecords, riskRecords

    var id: String { rawValue }

    func title(language: String) -> String {
        switch self {
        case .locationMap: language == "zh" ? "打开位置地图" : "Open location map"
        case .safeZonesMap: language == "zh" ? "查看安全区" : "View safe zones"
        case .tripRecords: language == "zh" ? "查看出行记录" : "View trip records"
        case .riskRecords: language == "zh" ? "查看风险统计" : "View risk statistics"
        }
    }
}

enum AgentLocalRequest: String, Codable {
    case seniorAge, seniorProfile, caregiverProfile, familyMembers, emergencyContacts, settings
    case locationMap, safeZonesMap, tripRecords, riskRecords

    var destination: AgentDestination? { AgentDestination(rawValue: rawValue) }

    static func allowed(_ requests: [String]?) -> [Self] {
        var seen: Set<Self> = []
        return (requests ?? []).compactMap(Self.init(rawValue:)).filter { seen.insert($0).inserted }
    }

    static func accessOff(language: String) -> String {
        language == "zh" ? "照护资料访问已关闭，可在 AI 设置中开启。" : "Care data access is off. You can enable it in AI Settings."
    }

    func text(from data: CaregiverSettingsData, language: String) -> String? {
        let zh = language == "zh"
        func field(_ label: String, _ value: String) -> String? {
            value.isEmpty ? nil : label + (zh ? "：" : ": ") + value
        }
        func toggle(_ label: String, _ enabled: Bool) -> String {
            field(label, enabled ? (zh ? "开启" : "On") : (zh ? "关闭" : "Off")) ?? label
        }
        switch self {
        case .seniorAge:
            return zh ? "未记录老人的年龄。" : "The senior’s age is not recorded."
        case .seniorProfile:
            return [
                zh ? "老人资料" : "Senior profile",
                field(zh ? "姓名" : "Name", data.senior.name),
                field(zh ? "电话" : "Phone", data.senior.phone),
                field(zh ? "与我的关系" : "Relationship to you", data.seniorRelationship)
            ].compactMap { $0 }.joined(separator: "\n")
        case .caregiverProfile:
            return [
                zh ? "家属资料" : "Caregiver profile",
                field(zh ? "姓名" : "Name", data.caregiver.name),
                field(zh ? "电话" : "Phone", data.caregiver.phone),
                field(zh ? "邮箱" : "Email", data.caregiver.email)
            ].compactMap { $0 }.joined(separator: "\n")
        case .familyMembers:
            let caregiver = data.caregiver
            let caregiverContact = caregiver.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? caregiver.email : caregiver.phone
            let members = [(caregiver.name, "", caregiverContact)] + data.members.map { ($0.name, $0.relationship, $0.phone) }
            return contactReply(members, chinese: zh)
        case .emergencyContacts:
            return contactReply(data.emergencyContacts.map { ($0.name, $0.relationship, $0.phone) }, chinese: zh)
        case .settings:
            return [
                zh ? "当前设置" : "Current settings",
                toggle(zh ? "照护资料访问" : "Care data access", data.allowAITripHistory),
                toggle(zh ? "自动导航" : "Automatic navigation", data.autoNavigation),
                toggle(zh ? "低风险通知" : "Low-risk notifications", data.lowRiskNotifications),
                toggle(zh ? "风险解除通知" : "Recovery notifications", data.recoveryNotifications),
                toggle(zh ? "监测受限通知" : "Limited monitoring notifications", data.limitedMonitoringNotifications)
            ].joined(separator: "\n")
        case .locationMap, .safeZonesMap, .tripRecords, .riskRecords:
            return nil
        }
    }

    private func contactReply(_ people: [(name: String, relationship: String, contact: String)], chinese: Bool) -> String {
        let contacts = people.map { person in
            (name: person.name.trimmingCharacters(in: .whitespacesAndNewlines),
             relationship: person.relationship.trimmingCharacters(in: .whitespacesAndNewlines),
             contact: person.contact.trimmingCharacters(in: .whitespacesAndNewlines))
        }.filter { !$0.name.isEmpty }
        let count = contacts.filter { !$0.contact.isEmpty }.count
        let family = self == .familyMembers
        let intro: String
        if chinese {
            let group = family ? "家人" : "紧急联系人"
            intro = count == 0
                ? "这部手机还没有登记\(group)的联系方式。"
                : "这部手机目前登记了 \(count) 位\(group)的联系方式。"
        } else {
            let group = family ? "family member" : "emergency contact"
            let category = family ? "family" : "emergency"
            intro = count == 0
                ? "No \(category) contact details are saved on this phone."
                : "This phone has contact details for \(count) \(group)\(count == 1 ? "" : "s")."
        }
        let rows = contacts.map { person in
            var fields = [person.name, person.relationship, person.contact].filter { !$0.isEmpty }
            if person.contact.isEmpty || EmailAddress.isValid(person.contact) {
                fields.append(chinese ? "未登记电话号码" : "No phone number saved")
            }
            return fields.joined(separator: " · ")
        }
        return rows.isEmpty ? intro : intro + "\n\n" + rows.joined(separator: "\n")
    }
}

enum AgentConversationTitle {
    /// Fixed titles for the demo questions, in the order of `DemoRecords.quickQuestions`.
    static let themes = ["Recent high-risk event", "August route deviations", "Unusual movement trends"]
    static func make(from question: String) -> String {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = DemoRecords.quickQuestions.firstIndex(where: { $0.lowercased() == text.lowercased() }) {
            return themes[index]
        }
        let sentence = String(text.prefix { !".!?。！？\n".contains($0) }).trimmingCharacters(in: .whitespaces)
        let content = sentence.isEmpty ? text : sentence
        if content.unicodeScalars.contains(where: { (0x3400...0x9FFF).contains($0.value) }) {
            return String(content.prefix(18)) + (content.count > 18 ? "…" : "")
        }
        let words = content.split(whereSeparator: \.isWhitespace)
        return words.prefix(6).joined(separator: " ") + (words.count > 6 ? "…" : "")
    }
}

/// A suggestion chip in a blank conversation: it shows the short topic, which is also the title
/// the conversation gets, and asks the full demo question (product design section 5.5).
struct AgentSuggestion: Equatable {
    let topic: String
    let question: String
    static let all: [AgentSuggestion] = zip(AgentConversationTitle.themes, DemoRecords.quickQuestions)
        .map { AgentSuggestion(topic: $0, question: $1) }
}

@MainActor final class AgentSessionStore: ObservableObject {
    static let storageKey = "safeorbit.agent.sessions.v1"
    @Published private(set) var sessions: [AgentConversation] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var storageError: String?
    @Published private var drafts: [UUID: String] = [:]
    @Published private var revealing: [UUID: String] = [:]
    private var emptySessions: [UUID: AgentConversation] = [:]
    private let defaults: UserDefaults
    private let service: (any AgentChatServing)?
    private let settings: CaregiverSettingsStore?
    private let additionalPrivacyValues: () -> (names: [String], otherValues: [String])
    @Published private(set) var pending: Set<UUID> = []
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         service: (any AgentChatServing)? = nil, settings: CaregiverSettingsStore? = nil,
         additionalPrivacyValues: @escaping () -> (names: [String], otherValues: [String]) = { ([], []) }) {
        self.defaults = defaults
        self.service = service
        self.settings = settings
        self.additionalPrivacyValues = additionalPrivacyValues
        self.now = now
        retryLoading()
    }
    var recent: [AgentConversation] {
        sessions.sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }
    func conversation(_ id: UUID) -> AgentConversation? {
        sessions.first { $0.id == id } ?? emptySessions[id]
    }
    @discardableResult func newConversation() -> UUID? {
        guard storageError == nil else { return nil }
        let id = UUID(), date = now()
        emptySessions[id] = AgentConversation(id: id, title: "New conversation", createdAt: date, updatedAt: date, messages: [])
        activeID = id
        return id
    }
    func open(_ id: UUID) {
        guard storageError == nil, conversation(id) != nil else { return }
        activeID = id
    }
    func showList() { activeID = nil }
    func displayedText(for message: AgentMessage) -> String { revealing[message.id] ?? message.text }
    func isRevealing(_ message: AgentMessage) -> Bool { revealing[message.id] != nil }
    func draft(for id: UUID) -> String { drafts[id] ?? "" }
    func setDraft(_ value: String, for id: UUID) { drafts[id] = value }
    /// Suggested-question chips belong to a blank conversation only. The first message, however it
    /// was sent, removes them for good; saved conversations always hold messages.
    func showsSuggestions(in id: UUID) -> Bool {
        conversation(id)?.messages.isEmpty == true
    }

    @discardableResult func send(_ question: String, in id: UUID, allowTripHistory: Bool) -> Bool {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard storageError == nil, !text.isEmpty, text.utf16.count <= 1000, !pending.contains(id), var session = conversation(id) else { return false }
        let date = now()
        if session.messages.isEmpty { session.title = AgentConversationTitle.make(from: text) }
        let message = AgentMessage(id: UUID(), fromCaregiver: true, text: text, createdAt: date,
                                   language: Self.language(for: text))
        session.messages.append(message)
        session.updatedAt = date
        guard save(session) else { return false }
        emptySessions[id] = nil; drafts[id] = nil
        request(message, in: id, allowTripHistory: allowTripHistory)
        return true
    }
    func retry(_ message: AgentMessage, in id: UUID, allowTripHistory: Bool) {
        guard storageError == nil, !pending.contains(id),
              conversation(id)?.messages.contains(where: { $0.id == message.id && $0.failed == true }) == true else { return }
        request(message, in: id, allowTripHistory: allowTripHistory)
    }
    private func save(_ session: AgentConversation) -> Bool {
        var updated = sessions.filter { $0.id != session.id }
        updated.append(session)
        guard persist(updated) else { return false }
        sessions = updated
        return true
    }
    private func request(_ message: AgentMessage, in id: UUID, allowTripHistory: Bool) {
        guard let messages = conversation(id)?.messages else { return }
        guard let service else { markFailed(message.id, in: id); return }
        let language = message.language ?? Self.language(for: message.text)
        let allowRecords = allowTripHistory && settings?.data.allowAITripHistory != false
        let filter = privacyFilter()
        let safeText = filter.redact(message.text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeText.isEmpty else { markFailed(message.id, in: id); return }
        let priorMessages = messages.prefix { $0.id != message.id }
        let history = Self.history(from: priorMessages, filter: filter)
        let recordContext = allowRecords
            ? priorMessages.reversed().compactMap(\.recordContext).first(where: { !$0.isEmpty }) : nil
        let question = AgentQuestion(question: String(decoding: safeText.utf16.prefix(1000), as: UTF16.self), language: language,
                                     allowTripHistory: allowRecords, history: history.isEmpty ? nil : history,
                                     recordContext: recordContext.map { Array($0.prefix(3)) })
        pending.insert(id)
        Task { @MainActor in
            defer { pending.remove(id) }
            do {
                let response = try await service.ask(question)
                let stillAllowed = allowRecords && settings?.data.allowAITripHistory != false
                let hasPrivateContent = response.outcome == "answered" || !response.citations.isEmpty
                    || response.localRequests?.isEmpty == false || response.recordContext?.isEmpty == false
                let withhold = !stillAllowed && hasPrivateContent
                let localRequests = stillAllowed ? AgentLocalRequest.allowed(response.localRequests) : []
                let paragraphs = withhold ? [AgentLocalRequest.accessOff(language: language)] : response.paragraphs
                guard !paragraphs.isEmpty || !localRequests.isEmpty else { throw APIError(kind: .other) }
                let citations = withhold ? [] : response.citations
                let retryable = !withhold && response.retryable == true
                let general = response.outcome == "general" && !hasPrivateContent && !retryable
                let answerText = paragraphs.joined(separator: "\n\n")
                let exchange = general ? [
                    AgentHistoryEntry(role: .user, text: question.question),
                    AgentHistoryEntry(role: .assistant, text: privacyFilter().redact(filter.redact(answerText)))
                ] : nil
                let context = stillAllowed ? response.recordContext.map { Array($0.prefix(3)) } : nil
                let answer = AgentMessage(id: UUID(), fromCaregiver: false,
                                          text: answerText, createdAt: now(), citations: citations,
                                          generalExchange: exchange, recordContext: context,
                                          localRequests: localRequests.isEmpty ? nil : localRequests, language: language)
                if paragraphs.count > 1 { revealing[answer.id] = paragraphs[0] }
                guard saveAnswer(answer, after: message.id, in: id, retryable: retryable) else {
                    revealing[answer.id] = nil
                    return
                }
                for index in paragraphs.indices.dropFirst() {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard conversation(id) != nil else { revealing[answer.id] = nil; return }
                    revealing[answer.id] = paragraphs.prefix(index + 1).joined(separator: "\n\n")
                }
                revealing[answer.id] = nil
            } catch {
                markFailed(message.id, in: id)
            }
        }
    }
    private func markFailed(_ questionID: UUID, in id: UUID) {
        guard var session = conversation(id), let index = session.messages.firstIndex(where: { $0.id == questionID }) else { return }
        session.messages[index].failed = true
        _ = save(session)
    }
    private func saveAnswer(_ answer: AgentMessage, after questionID: UUID, in id: UUID, retryable: Bool) -> Bool {
        guard var session = conversation(id),
              let index = session.messages.firstIndex(where: { $0.id == questionID }) else { return false }
        session.messages[index].failed = retryable ? true : nil
        let replyIndex = index + 1
        if session.messages.indices.contains(replyIndex), !session.messages[replyIndex].fromCaregiver {
            session.messages[replyIndex] = answer
        } else {
            session.messages.insert(answer, at: replyIndex)
        }
        return save(session)
    }

    private func privacyFilter() -> AgentPrivacyFilter {
        let data = settings?.data ?? CaregiverSettingsData()
        let more = additionalPrivacyValues()
        return AgentPrivacyFilter(
            names: [data.caregiver.name, data.senior.name, data.senior.callName] + data.members.map(\.name)
                + data.emergencyContacts.map(\.name) + more.names,
            otherValues: [data.caregiver.phone, data.caregiver.email, data.senior.phone, data.seniorRelationship]
                + data.members.flatMap { [$0.phone, $0.relationship] }
                + data.emergencyContacts.flatMap { [$0.phone, $0.relationship] } + more.otherValues)
    }

    private static func language(for text: String) -> String {
        text.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) } ? "zh" : "en"
    }

    private static func history(from messages: ArraySlice<AgentMessage>, filter: AgentPrivacyFilter) -> [AgentHistoryEntry] {
        var entries: [AgentHistoryEntry] = []
        var remaining = 4_000
        for (question, answer) in zip(messages, messages.dropFirst()).reversed() {
            guard question.fromCaregiver, question.failed != true, !answer.fromCaregiver,
                  let exchange = answer.generalExchange, exchange.map(\.role) == [.user, .assistant] else { continue }
            let user = filter.redact(exchange[0].text).trimmingCharacters(in: .whitespacesAndNewlines)
            let assistant = filter.redact(exchange[1].text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !user.isEmpty, !assistant.isEmpty, user.utf16.count < remaining else { break }
            let boundedReply = String(decoding: assistant.utf16.prefix(remaining - user.utf16.count), as: UTF16.self)
            entries.append(AgentHistoryEntry(role: .assistant, text: boundedReply))
            entries.append(AgentHistoryEntry(role: .user, text: user))
            remaining -= user.utf16.count + boundedReply.utf16.count
            if entries.count == 8 || remaining == 0 { break }
        }
        return entries.reversed()
    }
    @discardableResult func delete(_ id: UUID) -> Bool {
        guard storageError == nil, sessions.contains(where: { $0.id == id }) else { return false }
        let updated = sessions.filter { $0.id != id }
        guard persist(updated) else { return false }
        sessions = updated
        drafts[id] = nil
        if activeID == id { activeID = nil }
        return true
    }
    func retryLoading() {
        guard defaults.object(forKey: Self.storageKey) != nil else {
            sessions = []; storageError = nil; return
        }
        do {
            guard let data = defaults.data(forKey: Self.storageKey) else { throw SessionReadError.invalid }
            let decoded = try JSONDecoder().decode([AgentConversation].self, from: data)
            let messages = decoded.flatMap(\.messages)
            guard Set(decoded.map(\.id)).count == decoded.count,
                  Set(messages.map(\.id)).count == messages.count,
                  decoded.allSatisfy({ !$0.title.isEmpty && !$0.messages.isEmpty && $0.messages.first?.fromCaregiver == true }) else {
                throw SessionReadError.invalid
            }
            sessions = decoded.map { conversation in
                var conversation = conversation
                if let last = conversation.messages.indices.last, conversation.messages[last].fromCaregiver {
                    conversation.messages[last].failed = true
                }
                return conversation
            }
            storageError = nil
        } catch {
            storageError = "Could not read saved conversations. Your history has been kept. Try again."
        }
    }
    private enum SessionReadError: Error { case invalid }
    private func persist(_ updated: [AgentConversation]) -> Bool {
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: Self.storageKey)
            return true
        } catch {
            storageError = "Could not save this conversation. Try again."
            return false
        }
    }
}

struct AgentSessionPage: View {
    @ObservedObject var sessions: AgentSessionStore
    @ObservedObject var settings: CaregiverSettingsStore
    let keyboardVisible: Bool
    var isActive = true
    var openDestination: (AgentDestination) -> Void = { _ in }
    @State private var pendingDelete: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let id = sessions.activeID, sessions.conversation(id) != nil {
                AgentChatPage(keyboardVisible: keyboardVisible, settings: settings, sessions: sessions,
                              sessionID: id, isActive: isActive, back: sessions.showList,
                              openDestination: openDestination)
                    .id(id)
            } else {
                list
            }
        }
    }
    private var list: some View {
        VStack(spacing: 0) {
            CaregiverTopBar(height: dynamicTypeSize.isAccessibilitySize ? 74 : 47) {
                ZStack {
                    // The centered title keeps clear of the new-conversation button.
                    Text("Assistant").orbitDisplayFont(20).foregroundStyle(.white)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .layoutProbe("agent-title")
                        .padding(.horizontal, 60)
                    // The button reaches the screen edge so the glyph lands on the margin line.
                    HStack {
                        Spacer()
                        Button { sessions.newConversation() } label: {
                            Image(systemName: "plus").font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white).layoutProbe("agent-new-glyph")
                                .iconHitArea(.trailing, inset: OrbitLayout.pageMargin)
                        }.accessibilityLabel("New conversation").disabled(sessions.storageError != nil)
                            .layoutProbe("agent-new")
                    }
                }
            }
            // The conversation list has no cards: its title and rows start on the page margin line.
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent").caregiverText(.secondary).foregroundStyle(.secondary)
                    .layoutProbe("agent-recent-title")
                    .padding(.horizontal, OrbitLayout.pageMargin).padding(.top, 24).padding(.bottom, 8)
                if let error = sessions.storageError {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(error).caregiverText().fixedSize(horizontal: false, vertical: true)
                                .layoutProbe("agent-load-error")
                            Button("Retry") { sessions.retryLoading() }.caregiverText().frame(minHeight: 44)
                        }.padding(.horizontal, OrbitLayout.pageMargin).padding(.bottom, 101)
                    }
                } else {
                    List {
                        ForEach(sessions.recent) { session in
                            Button { sessions.open(session.id) } label: {
                                Text(session.title).caregiverText().foregroundStyle(.black)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutProbe("agent-row-\(session.id)")
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: OrbitLayout.pageMargin,
                                                      bottom: 0, trailing: OrbitLayout.pageMargin))
                            .listRowSeparator(.visible, edges: .bottom)
                            .listRowSeparatorTint(Color.black.opacity(0.12))
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            .listRowBackground(Color.white)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { pendingDelete = session.id } label: { Label("Delete", systemImage: "trash") }
                                    .tint(.red)
                            }
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 101) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .alert("Delete conversation?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) { if let id = pendingDelete { sessions.delete(id) }; pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("This conversation and all its messages will be deleted from this device.") }
    }
}

struct AgentChatPage: View {
    let keyboardVisible: Bool
    let isActive: Bool
    @ObservedObject var settings: CaregiverSettingsStore
    @StateObject private var speech = SpeechInput()
    @ObservedObject var sessions: AgentSessionStore
    let sessionID: UUID
    let back: () -> Void
    let openDestination: (AgentDestination) -> Void
    @State private var dictationTask: Task<Void, Never>?
    private var draft: String { sessions.draft(for: sessionID) }
    private var draftBinding: Binding<String> { Binding(get: { draft }, set: { sessions.setDraft($0, for: sessionID) }) }
    private var lines: [AgentMessage] { sessions.conversation(sessionID)?.messages ?? [] }
    private var showsSuggestions: Bool { sessions.showsSuggestions(in: sessionID) }
    @FocusState private var composing: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
#if DEBUG
    @Environment(\.agentChatTestDriver) private var testDriver
#endif

    @MainActor init(keyboardVisible: Bool, settings: CaregiverSettingsStore, sessions: AgentSessionStore,
                    sessionID: UUID, isActive: Bool = true, back: @escaping () -> Void,
                    openDestination: @escaping (AgentDestination) -> Void = { _ in }) {
        self.keyboardVisible = keyboardVisible
        self.isActive = isActive
        self.settings = settings
        self.sessions = sessions
        self.sessionID = sessionID
        self.back = back
        self.openDestination = openDestination
    }

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            CaregiverTopBar {
                HStack {
                    Button { stopInput(); back() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white).layoutProbe("chat-back-glyph")
                            .iconHitArea(.leading, inset: OrbitLayout.pageMargin)
                    }.accessibilityLabel("Back to conversations").layoutProbe("chat-back")
                    Spacer()
                }
            }
                .overlay(alignment: .bottom) {
                    Image(decorative: "AgentAvatar")
                        .resizable().scaledToFit()
                        .frame(width: 48, height: 48)
                        .frame(width: 68, height: 68)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(OrbitStyle.teal, lineWidth: 1) }
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                        .frame(width: 84, height: 84)
                        .offset(y: 40)
                }
                .zIndex(1)
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    GeometryReader { viewport in
                        ScrollView {
                            VStack(spacing: 28) {
                                Color.clear.frame(height: 45)
                                ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                    messageRow(line, index: index).id(line.id)
                                }
                                if showsSuggestions { suggestions }
                            }
                            .padding(.horizontal, OrbitLayout.pageMargin)
                            .padding(.bottom, 20)
                            // A blank conversation keeps its suggestions just above the composer; when they
                            // outgrow the viewport (large text, keyboard up) they scroll with the messages.
                            .frame(minHeight: showsSuggestions ? viewport.size.height : nil, alignment: .bottom)
                        }
                        .defaultScrollAnchor(showsSuggestions ? .bottom : nil)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: lines.last?.id) { _, id in
                            guard let id else { return }
                            withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                }
                if let message = speech.message {
                    Text(message).caregiverText(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, OrbitLayout.pageMargin).padding(.bottom, 5)
                }
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 1000 {
                    Text("Please keep your question to 1,000 characters or fewer.")
                        .caregiverText(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, OrbitLayout.pageMargin).padding(.bottom, 5)
                }
                if sessions.pending.contains(sessionID) {
                    ProgressView().accessibilityLabel("Waiting for an answer").padding(.bottom, 6)
                }
                composer
                    .layoutProbe("chat-composer")
                    .padding(.horizontal, OrbitLayout.pageMargin)
                    .padding(.bottom, keyboardVisible ? 8 : CaregiverBottomLayout.gap(safeAreaBottom: geometry.safeAreaInsets.bottom) - geometry.safeAreaInsets.bottom)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .onChange(of: speech.transcript) { _, value in if isActive && !value.isEmpty { sessions.setDraft(value, for: sessionID) } }
        .onDisappear { stopInput() }
        .onChange(of: isActive) { _, active in
            if !active { stopInput() }
        }
        .onChange(of: speech.listening) { _, listening in
            if listening && !isActive { speech.stop() }
        }
#if DEBUG
        .onAppear {
            testDriver?.perform = { action in
                switch action {
                case .tapSuggestion(let index): askSuggestion(index)
                case .typeAndSend(let text): sessions.setDraft(text, for: sessionID); send()
                }
            }
        }
#endif
        }
    }

    private func messageRow(_ line: AgentMessage, index: Int) -> some View {
        let revealing = sessions.isRevealing(line)
        let language = line.language ?? "en"
        let hasLocalRequests = line.localRequests?.isEmpty == false
        let requests = !revealing && settings.data.allowAITripHistory ? line.localRequests ?? [] : []
        let destinations = requests.compactMap(\.destination)
        let localText = hasLocalRequests && !settings.data.allowAITripHistory
            ? [AgentLocalRequest.accessOff(language: language)]
            : requests.compactMap { $0.text(from: settings.data, language: language) }
        let text = ([sessions.displayedText(for: line)] + localText).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return HStack {
            if line.fromCaregiver { Spacer(minLength: 52) }
            VStack(alignment: .leading, spacing: 8) {
                if !text.isEmpty {
                    Text(text)
                        .caregiverText()
                        .foregroundStyle(line.fromCaregiver ? .white : .black)
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(line.fromCaregiver ? OrbitStyle.teal : OrbitStyle.pale,
                                    in: RoundedRectangle(cornerRadius: 20))
                        .layoutProbe("chat-bubble-\(line.id)")
                        .frame(maxWidth: 315, alignment: line.fromCaregiver ? .trailing : .leading)
                        .accessibilityLabel(line.fromCaregiver ? "Your message: \(text)" : "Agent: \(text)")
                }
                if !revealing, let citations = line.citations {
                    ForEach(Array(citations.enumerated()), id: \.offset) { _, citation in
                        Text([citation.label, citation.date, citation.startDate, citation.endDate].compactMap { $0 }.joined(separator: " · "))
                            .caregiverText(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(destinations) { destination in
                    Button {
                        stopInput()
                        openDestination(destination)
                    } label: {
                        Label(destination.title(language: language), systemImage: "arrow.up.right.square")
                            .caregiverText().frame(minHeight: 44)
                    }
                    .foregroundStyle(OrbitStyle.teal)
                    .layoutProbe("chat-destination-\(destination.rawValue)")
                }
                if line.failed == true {
                    let hasPartialReply = lines.indices.contains(index + 1) && !lines[index + 1].fromCaregiver
                    Button(language == "zh" ? "重试" : "Retry") {
                        sessions.retry(line, in: sessionID, allowTripHistory: settings.data.allowAITripHistory)
                    }
                    .caregiverText(.caption).frame(minHeight: 44)
                    .disabled(sessions.pending.contains(sessionID))
                    Text(hasPartialReply
                         ? (language == "zh" ? "部分资料暂不可用，可重试。" : "Some information is unavailable. Try again.")
                         : (language == "zh" ? "暂时无法回答，请重试。" : "Could not get an answer. Try again."))
                        .caregiverText(.caption)
                }
            }
            if !line.fromCaregiver { Spacer(minLength: 30) }
        }
    }

    /// One chip per suggestion, each on its own line from the page margin (product design
    /// section 10). A chip shows the short topic in secondary text and asks its full question
    /// exactly as typing it and pressing send would (section 5.5).
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(AgentSuggestion.all.enumerated()), id: \.offset) { index, suggestion in
                Button { askSuggestion(index) } label: {
                    Text(suggestion.topic)
                        .caregiverText(.secondary)
                        .foregroundStyle(OrbitStyle.teal)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutProbe("chat-suggestion-text-\(index)")
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(minHeight: OrbitLayout.minimumHitSize)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(OrbitStyle.teal, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(suggestion.topic)
                .accessibilityHint("Asks: " + suggestion.question)
                .layoutProbe("chat-suggestion-\(index)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dictation, field and send in one row; at accessibility text sizes the field takes the full
    /// width and the two buttons sit below it, so the field never becomes too narrow (rule 8).
    private var composer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    questionField
                    HStack(spacing: 7) {
                        dictationButton
                        Spacer(minLength: 0)
                        sendButton
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 7) {
                    dictationButton
                    questionField
                    sendButton
                }
            }
        }
    }

    private var dictationButton: some View {
        Button {
            composing = false
            dictationTask?.cancel()
            dictationTask = Task {
                await speech.toggle()
                if Task.isCancelled { speech.stop() }
            }
        } label: {
            Image(systemName: speech.listening ? "stop.fill" : "mic.fill")
                .font(.system(size: 22)).frame(width: 44, height: 44)
                .foregroundStyle(.black).background(.white, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
        }
        .accessibilityLabel(speech.listening ? "Stop dictation" : "Start dictation")
        .layoutProbe("chat-mic")
    }

    private var questionField: some View {
        TextField("Ask a question", text: draftBinding, axis: .vertical)
            .lineLimit(1...4)
            .caregiverText()
            .padding(.horizontal, 15).padding(.vertical, 11)
            .background(.white, in: Capsule())
            .layoutProbe("chat-field")
            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
            .focused($composing)
            .submitLabel(.send)
            .onSubmit(send)
            .accessibilityLabel("Question")
    }

    @ViewBuilder private var sendButton: some View {
        if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white).background(OrbitStyle.teal, in: Circle())
            }.accessibilityLabel("Send question")
                .disabled(sessions.pending.contains(sessionID) || draft.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 1000)
                .layoutProbe("chat-send")
        }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, question.utf16.count <= 1000 else { return }
        speech.stop()
        composing = false
        ask(question)
    }

    private func stopInput() {
        composing = false
        dictationTask?.cancel()
        dictationTask = nil
        speech.stop()
    }

    private func ask(_ question: String) {
        stopInput()
        sessions.send(question, in: sessionID, allowTripHistory: settings.data.allowAITripHistory)
    }

    private func askSuggestion(_ index: Int) {
        ask(AgentSuggestion.all[index].question)
    }
}

#if DEBUG
// Internal render-test entry: runs the same functions as a suggestion chip and the send button.
// This does not substitute for a physical touch or a device acceptance test.
enum AgentChatTestAction {
    case tapSuggestion(Int), typeAndSend(String)
}
final class AgentChatTestDriver {
    var perform: ((AgentChatTestAction) -> Void)?
}
private struct AgentChatTestDriverKey: EnvironmentKey {
    static let defaultValue: AgentChatTestDriver? = nil
}
extension EnvironmentValues {
    var agentChatTestDriver: AgentChatTestDriver? {
        get { self[AgentChatTestDriverKey.self] }
        set { self[AgentChatTestDriverKey.self] = newValue }
    }
}
#endif
