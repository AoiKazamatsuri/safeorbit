import SwiftUI

private struct ChatLine: Identifiable {
    let id = UUID()
    let fromCaregiver: Bool
    let text: String
}

struct AgentChatPage: View {
    let keyboardVisible: Bool
    @StateObject private var speech = SpeechInput()
    @State private var draft = ""
    @State private var lines: [ChatLine] = [
        ChatLine(fromCaregiver: true, text: DemoRecords.quickQuestions[0]),
        ChatLine(fromCaregiver: false, text: DemoRecords.answer(to: DemoRecords.quickQuestions[0]))
    ]
    @FocusState private var composing: Bool

    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar { Color.clear }
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
                                        .font(.system(size: 17))
                                        .foregroundStyle(line.fromCaregiver ? .white : .black)
                                        .padding(.horizontal, 16).padding(.vertical, 13)
                                        .background(line.fromCaregiver ? OrbitStyle.teal : OrbitStyle.pale,
                                                    in: RoundedRectangle(cornerRadius: 18))
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
                    Text(message).font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.bottom, 5)
                }
                composer
                    .padding(.horizontal, 16)
                    .padding(.bottom, keyboardVisible ? 8 : 101)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 29, topTrailingRadius: 29))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .onChange(of: speech.transcript) { _, value in if !value.isEmpty { draft = value } }
        .onDisappear { speech.stop() }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 7) {
            Button {
                composing = false
                Task { await speech.toggle() }
            } label: {
                Image(systemName: speech.listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22)).frame(width: 44, height: 44)
                    .foregroundStyle(.black).background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
            }
            .accessibilityLabel(speech.listening ? "Stop dictation" : "Start dictation")
            TextField("Ask a question", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 16))
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
        draft = ""
        composing = false
        ask(question)
    }

    private func ask(_ question: String) {
        lines.append(ChatLine(fromCaregiver: true, text: question))
        lines.append(ChatLine(fromCaregiver: false, text: DemoRecords.answer(to: question)))
    }
}
