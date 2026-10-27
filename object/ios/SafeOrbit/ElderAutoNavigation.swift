import Foundation
import AVFoundation
import UIKit
import UserNotifications

// Elder phone, low risk (product design section 3.4, task T38): the care API asks this phone to start
// navigation home. The phone speaks a fixed reminder, starts the same navigation as "Go Home", and
// reports whether it started. When it cannot start, a time-sensitive local notification lets her start
// it with one tap (engineering architecture section 10, fallback).

@MainActor protocol ElderActionReporting {
    func report(_ actionID: String, _ body: ActionResultBody) async throws
}
@MainActor struct DeviceActionReporter: ElderActionReporting {
    let device: DemoDevice
    func report(_ actionID: String, _ body: ActionResultBody) async throws {
        let _: ActionResultReply = try await device.request("actions/\(actionID)/result", method: "POST", body: OnboardingAPI.json(body))
    }
}

@MainActor protocol ElderReminderSpeaking {
    /// Speaks and returns when the sentence has been said (or given up on).
    func speak(_ text: String, volume: Float) async
}
@MainActor protocol ElderAudioSessionControlling {
    /// Activates audio for spoken prompts; false when iOS refuses (e.g. in the background without audio).
    func activateForPrompts() -> Bool
}
@MainActor protocol ElderLocalNotifying {
    func postStartNavigationFallback() async
}

/// Spoken prompts play over other audio (ducked) and also while the app is in the background, which
/// the "audio" background mode allows for a mixable session. Lock-screen behaviour needs a real iPhone.
@MainActor final class SystemElderAudioSession: ElderAudioSessionControlling {
    static let shared = SystemElderAudioSession()
    func configure() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
    }
    func activateForPrompts() -> Bool {
        configure()
        do { try AVAudioSession.sharedInstance().setActive(true); return true } catch { return false }
    }
}

@MainActor final class SystemReminderVoice: NSObject, ElderReminderSpeaking, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var finished: CheckedContinuation<Void, Never>?
    private var generation = 0
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, volume: Float) async {
        finishCurrent()
        generation += 1
        let current = generation
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        await withCheckedContinuation { continuation in
            finished = continuation
            synthesizer.speak(utterance)
            // Never hold navigation back for long if the synthesizer stays silent.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                if self?.generation == current { self?.finishCurrent() }
            }
        }
    }
    private func finishCurrent() { let pending = finished; finished = nil; pending?.resume() }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishCurrent() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishCurrent() }
    }
}

enum ElderFallbackNotification {
    static let kind = "elderStartNavigation"
    static let identifier = "safeorbit.elder.start-navigation"
    static let body = "Tap to start navigation home"
}
@MainActor struct SystemElderNotifier: ElderLocalNotifying {
    func postStartNavigationFallback() async {
        let content = UNMutableNotificationContent()
        content.title = "SafeOrbit"
        content.body = ElderFallbackNotification.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["kind": ElderFallbackNotification.kind]
        let request = UNNotificationRequest(identifier: ElderFallbackNotification.identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

@MainActor final class ElderAutoNavigation: ObservableObject {
    enum Outcome: Equatable { case started, failed(String) }
    /// Result of the latest automatic start, for the record and tests.
    @Published private(set) var lastOutcome: Outcome?
    /// Her call name for the reminder ("Grandma, let's go home.").
    var callName = ""
    /// Starts navigation home exactly like "Go Home"; returns nil when a route is shown, else why not.
    /// Set by the elder home page while it is on screen.
    var startNavigation: (() async -> String?)?
    var isNavigatingHome: () -> Bool = { false }
    var isAppActive: () -> Bool = { UIApplication.shared.applicationState == .active }
    /// Elder voice switch and volume (0 silences the reminder).
    var reminderVolume: () -> Double = { 0.8 }
    /// Set once the elder phone's device exists; results wait in `unreported` until then.
    var actionReporter: ElderActionReporting?
    private let voice: ElderReminderSpeaking
    private let audio: ElderAudioSessionControlling
    private let notifier: ElderLocalNotifying
    private var handled: Set<String> = []
    /// Results the care API has not acknowledged yet (offline); sent again when the action repeats.
    private(set) var unreported: [String: ActionResultBody] = [:]

    init(reporter: ElderActionReporting? = nil, voice: ElderReminderSpeaking? = nil,
         audio: ElderAudioSessionControlling? = nil, notifier: ElderLocalNotifying? = nil) {
        actionReporter = reporter
        self.voice = voice ?? SystemReminderVoice()
        self.audio = audio ?? SystemElderAudioSession.shared
        self.notifier = notifier ?? SystemElderNotifier()
    }

    static func reminder(callName: String) -> String {
        let name = callName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Let's go home." : "\(name), let's go home."
    }

    /// Handles the actions of one upload reply: each action id runs and is reported once.
    func receive(_ actions: [ElderAction], now: Date = Date()) async {
        for action in actions {
            if let body = unreported[action.id] { await report(action.id, body); continue }
            guard action.type == ElderAction.startNavigation, !handled.contains(action.id) else { continue }
            // An expired request gets a new id from the care API if she still needs help.
            if let expiry = action.expiresAt, expiry <= now { continue }
            handled.insert(action.id)
            await execute(action)
        }
    }

    private func execute(_ action: ElderAction) async {
        if isNavigatingHome() { return await finish(action.id, .started) }
        let active = isAppActive()
        let audible = audio.activateForPrompts()
        if !active && !audible { return await fallback(action.id, reason: "App in the background could not speak") }
        let volume = reminderVolume()
        if volume > 0 { await voice.speak(Self.reminder(callName: callName), volume: Float(min(1, volume))) }
        guard let startNavigation else { return await fallback(action.id, reason: "App was not ready to navigate") }
        if let reason = await startNavigation() { await fallback(action.id, reason: reason) }
        else { await finish(action.id, .started) }
    }

    private func fallback(_ id: String, reason: String) async {
        await notifier.postStartNavigationFallback()
        await finish(id, .failed(reason))
    }

    private func finish(_ id: String, _ outcome: Outcome) async {
        lastOutcome = outcome
        switch outcome {
        case .started: await report(id, .started)
        case .failed(let reason): await report(id, .failed(reason))
        }
    }

    private func report(_ id: String, _ body: ActionResultBody) async {
        guard let actionReporter else { unreported[id] = body; return }
        do { try await actionReporter.report(id, body); unreported[id] = nil }
        catch let error as APIError where error.kind == .network || error.kind == .unavailable || error.kind == .unauthorized {
            unreported[id] = body
        } catch {
            // 404 or 409: withdrawn, expired or already answered; nothing left to tell the care API.
            unreported[id] = nil
        }
    }

    /// Plain reason for the caregiver's event page when navigation home does not start.
    static func reason(for issue: NavigationIssue?) -> String {
        switch issue {
        case .missingHome?: return "No home location on her phone"
        case .sdkNotReady?: return "Route planning failed: map service unavailable on her phone"
        case .locationDenied?: return "Location access is off on her phone"
        case .locationUnavailable?: return "No accurate location on her phone yet"
        case .routeConfiguration?: return "Route planning failed: map key not set up for walking routes"
        case .routeTimedOut?: return "Route planning failed: request timed out"
        case .routeNetworkUnavailable?: return "Route planning failed: no internet on her phone"
        case .routeServiceUnavailable?, .routeUnavailable?: return "Route planning failed: no walking route"
        case .missingDestination?, .staleDestination?, nil: return "Route planning failed"
        }
    }
}
