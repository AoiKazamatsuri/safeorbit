import SwiftUI
import Combine
import CoreLocation

@MainActor final class HomeLocationStore: ObservableObject {
    static let key = "safeorbit.home.coordinate.v1"
    @Published private(set) var point: GeoPoint?
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let point = try? JSONDecoder().decode(GeoPoint.self, from: data), point.isValid {
            self.point = point
        }
    }
    func save(_ point: GeoPoint) {
        guard point.isValid else { return }
        self.point = point
        defaults.set(try? JSONEncoder().encode(point), forKey: Self.key)
    }
}
@MainActor final class ElderNavigationVoice: NavigationSpeaking {
    var enabled = true
    var volume = 0.8
    private let output: ElderVoiceOutput
    init(output: ElderVoiceOutput? = nil) { self.output = output ?? SystemElderVoice() }
    func speak(_ text: String) {
        guard enabled, volume > 0 else { return }
        output.speak(text, volume: Float(volume), language: "en-US")
    }
    func stop() { output.stop() }
}
@MainActor final class ElderLiveNavigation: ObservableObject {
    let home: HomeLocationStore
    let navigation: WalkingNavigationModel
    private let provider: WalkingRouteProvider
    private let voice: ElderNavigationVoice
    private var observations: Set<AnyCancellable> = []
    @Published private(set) var currentFix: NavigationFix?
    @Published private(set) var locationIssue: NavigationIssue?
    @Published var showingHomeSetup = false
    private var waiting: Task<Void, Never>?
    private var running = false
    init(home: HomeLocationStore? = nil, provider: WalkingRouteProvider? = nil,
         navigationProvider: WalkingRouteProvider? = nil, voice: ElderNavigationVoice? = nil) {
        let home = home ?? HomeLocationStore()
        let voice = voice ?? ElderNavigationVoice()
        self.home = home; self.provider = provider ?? AMapWalkingRouteProvider(); self.voice = voice
        navigation = WalkingNavigationModel(provider: navigationProvider ?? AMapWalkingRouteProvider(), voice: voice, destinationKind: .home)
        navigation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &observations)
        home.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &observations)
    }
    var point: GeoPoint? {
        if navigation.isPresented, let fix = navigation.fix, fix.isUsable(at: Date()) { return fix.point }
        return currentFix.flatMap { $0.isUsable(at: Date()) ? $0.point : nil }
    }
    var homeSnapshot: ElderLocationSnapshot? {
        home.point.map { ElderLocationSnapshot(coordinate: $0, recordedAt: Date(), heading: nil, status: nil, batteryPercent: nil, address: nil, trail: [], safeZones: []) }
    }
    func startLocation() {
        guard !running, AMapRuntime.prepare(), !navigation.isPresented else { return }
        running = true
        provider.startUpdates { [weak self] result in
            switch result {
            case .success(let fix):
                self?.currentFix = fix
                self?.locationIssue = fix.isUsable(at: Date()) ? nil : .locationUnavailable
            case .failure(let issue): self?.locationIssue = issue
            }
        }
        waiting = Task { [weak self] in
            guard let self else { return }
            do { _ = try await provider.currentPoint() }
            catch is CancellationError {}
            catch { locationIssue = error as? NavigationIssue ?? .locationUnavailable }
        }
    }
    func goHome() async {
        guard home.point != nil else { showingHomeSetup = true; return }
        stopLocation()
        await navigation.start(to: homeSnapshot)
    }
    func cancel() { navigation.end(); startLocation() }
    func updateVoice(enabled: Bool, volume: Double, calling: Bool) {
        voice.enabled = enabled && !calling
        voice.volume = volume.isFinite ? min(1, max(0, volume)) : 0
        if !voice.enabled || voice.volume == 0 { voice.stop() }
    }
    func pause() { stopLocation(); navigation.pause(); voice.stop() }
    func resume() async {
        if navigation.isPresented { await navigation.resume(to: homeSnapshot) }
        else { startLocation() }
    }
    func stop() { stopLocation(); navigation.end() }
    private func stopLocation() { running = false; waiting?.cancel(); waiting = nil; provider.stopUpdates() }
}
