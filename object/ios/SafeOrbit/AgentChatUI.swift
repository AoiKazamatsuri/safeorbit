import SwiftUI

struct AgentMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let fromCaregiver: Bool
    let text: String
    let createdAt: Date
}

struct AgentConversation: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [AgentMessage]
}

enum AgentConversationTitle {
    static func make(from question: String) -> String {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let themes = ["Recent high-risk event", "August route deviations", "Unusual movement trends"]
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

@MainActor final class AgentSessionStore: ObservableObject {
    static let storageKey = "safeorbit.agent.sessions.v1"
    @Published private(set) var sessions: [AgentConversation] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var storageError: String?
    @Published private var drafts: [UUID: String] = [:]
    private var emptySessions: [UUID: AgentConversation] = [:]
    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
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
    func draft(for id: UUID) -> String { drafts[id] ?? "" }
    func setDraft(_ value: String, for id: UUID) { drafts[id] = value }

    @discardableResult func send(_ question: String, in id: UUID, allowTripHistory: Bool) -> Bool {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard storageError == nil, !text.isEmpty, var session = conversation(id) else { return false }
        let date = now()
        if session.messages.isEmpty { session.title = AgentConversationTitle.make(from: text) }
        session.messages.append(AgentMessage(id: UUID(), fromCaregiver: true, text: text, createdAt: date))
        session.messages.append(AgentMessage(id: UUID(), fromCaregiver: false,
                                            text: DemoRecords.answer(to: text, allowTripHistory: allowTripHistory), createdAt: date))
        session.updatedAt = date
        var updated = sessions.filter { $0.id != id }
        updated.append(session)
        guard persist(updated) else { return false }
        sessions = updated
        emptySessions[id] = nil
        drafts[id] = nil
        return true
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
            sessions = decoded
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
    @State private var pendingDelete: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let id = sessions.activeID, sessions.conversation(id) != nil {
                AgentChatPage(keyboardVisible: keyboardVisible, settings: settings, sessions: sessions,
                              sessionID: id, isActive: isActive, back: sessions.showList)
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
                    Text("Assistant").orbitDisplayFont(20).foregroundStyle(.white)
                    HStack {
                        Spacer()
                        Button { sessions.newConversation() } label: {
                            Image(systemName: "plus").font(.system(size: 22, weight: .medium))
                                .frame(width: 44, height: 44).foregroundStyle(.white)
                        }.accessibilityLabel("New conversation").disabled(sessions.storageError != nil)
                    }.padding(.trailing, 12)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent").caregiverText(.secondary).foregroundStyle(.secondary)
                    .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 8)
                if let error = sessions.storageError {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(error).caregiverText().fixedSize(horizontal: false, vertical: true)
                            Button("Retry") { sessions.retryLoading() }.caregiverText().frame(minHeight: 44)
                        }.padding(.horizontal, 28).padding(.bottom, 101)
                    }
                } else {
                    List {
                        ForEach(sessions.recent) { session in
                            Button { sessions.open(session.id) } label: {
                                Text(session.title).caregiverText().foregroundStyle(.black)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
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
    @State private var dictationTask: Task<Void, Never>?
    private var draft: String { sessions.draft(for: sessionID) }
    private var draftBinding: Binding<String> { Binding(get: { draft }, set: { sessions.setDraft($0, for: sessionID) }) }
    private var lines: [AgentMessage] { sessions.conversation(sessionID)?.messages ?? [] }
    @FocusState private var composing: Bool

    @MainActor init(keyboardVisible: Bool, settings: CaregiverSettingsStore, sessions: AgentSessionStore,
                    sessionID: UUID, isActive: Bool = true, back: @escaping () -> Void) {
        self.keyboardVisible = keyboardVisible
        self.isActive = isActive
        self.settings = settings
        self.sessions = sessions
        self.sessionID = sessionID
        self.back = back
    }

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            CaregiverTopBar {
                HStack {
                    Button { stopInput(); back() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                    }.accessibilityLabel("Back to conversations")
                    Spacer()
                }.padding(.leading, 12)
            }
                .overlay(alignment: .bottom) {
                    Image("AgentAvatar")
                        .resizable().scaledToFit()
                        .frame(width: 84, height: 84)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                        .offset(y: 40)
                }
                .zIndex(1)
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 28) {
                            Color.clear.frame(height: 45)
                            ForEach(lines) { line in
                                HStack {
                                    if line.fromCaregiver { Spacer(minLength: 52) }
                                    Text(line.text)
                                        .caregiverText()
                                        .foregroundStyle(line.fromCaregiver ? .white : .black)
                                        .padding(.horizontal, 16).padding(.vertical, 13)
                                        .background(line.fromCaregiver ? OrbitStyle.teal : OrbitStyle.pale,
                                                    in: RoundedRectangle(cornerRadius: 20))
                                        .frame(maxWidth: 315, alignment: line.fromCaregiver ? .trailing : .leading)
                                    if !line.fromCaregiver { Spacer(minLength: 30) }
                                }
                                .id(line.id)
                                .accessibilityLabel(line.fromCaregiver ? "Your message: \(line.text)" : "Agent: \(line.text)")
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: lines.count) { _, _ in
                        guard let last = lines.last else { return }
                        withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                if let message = speech.message {
                    Text(message).caregiverText(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.bottom, 5)
                }
                composer
                    .padding(.horizontal, 16)
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
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 7) {
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
            TextField("Ask a question", text: draftBinding, axis: .vertical)
                .lineLimit(1...4)
                .caregiverText()
                .padding(.horizontal, 15).padding(.vertical, 11)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                .focused($composing)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityLabel("Question")
            Menu {
                ForEach(DemoRecords.quickQuestions, id: \.self) { question in
                    Button(question) { ask(question) }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.black).background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
            }
            .accessibilityLabel("Suggested questions")
            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white).background(OrbitStyle.teal, in: Circle())
                }.accessibilityLabel("Send question")
            }
        }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
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
}
