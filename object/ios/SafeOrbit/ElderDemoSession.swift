import SwiftUI
import AVFoundation
import MapKit

enum DemoAppRole { case caregiver, elder }
@MainActor final class DemoRoleRouter: ObservableObject {
    @Published private(set) var role: DemoAppRole?
    func choose(_ role: DemoAppRole) { self.role = role }
    func returnToSelection() { role = nil }
}

enum ElderCopy {
    static func text(_ english: String, _ chinese: String, locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? chinese : english
    }
}

@MainActor protocol ElderVoiceOutput {
    func speak(_ text: String, volume: Float, language: String)
    func stop()
}
@MainActor final class SystemElderVoice: ElderVoiceOutput {
    private let synthesizer = AVSpeechSynthesizer()
    func speak(_ text: String, volume: Float, language: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

// Call and confirmation state; demo guidance is restricted to explicitly constructed preview sessions.
@MainActor final class ElderDemoSession: ObservableObject {
    @Published private(set) var navigating = false
    @Published private(set) var calling = false
    @Published private(set) var confirmingEnd = false
    @Published var showingSettings = false
    @Published private(set) var voiceOn = true
    @Published private(set) var volume: Double = 0.8
    let usesLiveNavigation: Bool
    private let voice: ElderVoiceOutput
    init(voice: ElderVoiceOutput? = nil, usesLiveNavigation: Bool = false) {
        self.voice = voice ?? SystemElderVoice(); self.usesLiveNavigation = usesLiveNavigation
    }
    func startNavigation(locale: Locale) {
        navigating = true; calling = false; confirmingEnd = false
        announce(locale: locale)
    }
    func showCall() { calling = true; suspendSpeech() }
    func dismissCall(locale: Locale) { calling = false; announce(locale: locale) }
    func requestEnd() { confirmingEnd = true }
    func cancelEnd() { confirmingEnd = false }
    func confirmEnd() {
        navigating = false; confirmingEnd = false; calling = false
        suspendSpeech()
    }
    func setVoice(_ enabled: Bool, locale: Locale) {
        voiceOn = enabled
        if enabled { announce(locale: locale) } else { suspendSpeech() }
    }
    func setVolume(_ value: Double) {
        volume = value.isFinite ? min(1, max(0, value)) : 0
        if volume == 0 { suspendSpeech() }
    }
    func announce(locale: Locale) {
        guard !usesLiveNavigation, navigating, !calling, voiceOn, volume > 0 else { return }
        voice.speak(ElderCopy.text("Demo guidance. Turn right in eighty metres. Going home.",
                                  "演示导航。前方八十米右转，正在回家。", locale: locale),
                    volume: Float(volume), language: locale.language.languageCode?.identifier == "zh" ? "zh-CN" : "en-US")
    }
    func suspendSpeech() { voice.stop() }
}

enum ElderDemoMapData {
    // Illustrative geometry uses the existing Nanjing sample; it is not a live position or planned route.
    static let home = LocationPreviewData.startingPoint
    static let position = LocationPreviewData.trail[2]
    static let market = LocationPreviewData.trail[4]
    static let route = Array(LocationPreviewData.trail.prefix(3).reversed())
    static var region: MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 32.0593, longitude: 118.7685),
                           span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006))
    }
}
