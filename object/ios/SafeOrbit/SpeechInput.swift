import Foundation
import AVFoundation
import Speech

@MainActor final class SpeechInput: ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var message: String?
    @Published private(set) var transcript = ""

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    func toggle() async {
        if listening { stop(showEmptyResult: true); return }
        await start()
    }

    private func start() async {
        message = nil
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechPermission == .authorized else {
            message = "Speech recognition is unavailable. Allow it in Settings to use the microphone."
            return
        }
        let microphonePermission = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphonePermission else {
            message = "Microphone access is off. Allow it in Settings to dictate a question."
            return
        }
        let language = Locale.preferredLanguages.first ?? "en-US"
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            message = "Speech recognition is not available for this language right now."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let hardwareFormat = input.inputFormat(forBus: 0)
            let format = input.outputFormat(forBus: 0)
            guard session.isInputAvailable,
                  hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0,
                  format.sampleRate > 0, format.channelCount > 0 else {
                message = "No microphone input is available on this device."
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            listening = true
            transcript = ""
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.listening else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal { self.stop(showEmptyResult: true); return }
                    }
                    if error != nil {
                        self.message = self.transcript.isEmpty ? "Could not understand the recording. Try again." : nil
                        self.stop()
                    }
                }
            }
        } catch {
            message = "Could not start the microphone. Try again."
            stop()
        }
    }

    func stop(showEmptyResult: Bool = false) {
        guard listening || engine.isRunning || tapInstalled || task != nil || request != nil else { return }
        let hadNoWords = listening && transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if showEmptyResult && hadNoWords && message == nil {
            message = "No speech was recognized. Try again."
        }
    }
}
