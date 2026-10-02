import SwiftUI
import AVFoundation

struct QRScanner: UIViewControllerRepresentable {
    var completion: (Result<String, Error>) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController(); controller.completion = completion; return controller
    }
    func updateUIViewController(_ controller: ScannerController, context: Context) {}
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let capture = AVCaptureSession()
    private let queue = DispatchQueue(label: "org.safeorbit.camera")
    private var layer: AVCaptureVideoPreviewLayer?
    private var delivered = false
    var completion: ((Result<String, Error>) -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let preview = AVCaptureVideoPreviewLayer(session: capture)
        preview.videoGravity = .resizeAspectFill; view.layer.addSublayer(preview); layer = preview
        queue.async { [weak self] in self?.configure() }
    }
    private func configure() {
        do {
            guard let device = AVCaptureDevice.default(for: .video) else { throw APIError(kind: .other) }
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            capture.beginConfiguration()
            guard capture.canAddInput(input), capture.canAddOutput(output) else {
                capture.commitConfiguration(); throw APIError(kind: .other)
            }
            capture.addInput(input); capture.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            capture.commitConfiguration()
            capture.startRunning()
        } catch { DispatchQueue.main.async { [weak self] in self?.deliver(.failure(error)) } }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); layer?.frame = view.bounds }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        queue.async { [capture] in if capture.isRunning { capture.stopRunning() } }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let value = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
        deliver(.success(value))
    }
    private func deliver(_ result: Result<String, Error>) {
        guard !delivered else { return }; delivered = true
        queue.async { [capture] in if capture.isRunning { capture.stopRunning() } }
        completion?(result)
    }
}
struct ScanPage: View {
    var busy: Bool
    @Binding var payload: String
    var bind: (String) -> Void
    @State private var showScanner = false
    @State private var cameraMessage: String?
    @State private var denied = false
    @Environment(\.openURL) private var openURL
    var body: some View {
        PageLayout(step: "", title: "Connect phone", subtitle: "Scan the code on your family's phone.") {
            Card {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 76, weight: .light)).foregroundStyle(OrbitStyle.teal)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                PrimaryButton(title: "Scan code", busy: busy) { Task { await openCamera() } }
                if let cameraMessage { Text(cameraMessage).font(.subheadline).foregroundStyle(.secondary) }
                if denied { Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } }
            }
            Card {
                Text("Connection link").font(.subheadline)
                TextField("Paste link", text: $payload, axis: .vertical)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .lineLimit(2...4).padding(14).overlay(RoundedRectangle(cornerRadius: 24).stroke(OrbitStyle.border, lineWidth: 1))
                    .accessibilityLabel("Connection link")
                if !payload.isEmpty && BindingPayload.token(from: payload) == nil {
                    Text("Enter a valid SafeOrbit link.").font(.footnote).foregroundStyle(.red)
                }
                PrimaryButton(title: "Connect", busy: busy, enabled: BindingPayload.token(from: payload) != nil) { bind(payload) }
            }
        }.sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScanner { result in
                    showScanner = false
                    switch result {
                    case .success(let value): payload = value; bind(value)
                    case .failure: cameraMessage = "Camera unavailable. Retry or paste a link."
                    }
                }.ignoresSafeArea(edges: .bottom).navigationTitle("Scan code")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showScanner = false } } }
            }
        }
    }
    @MainActor private func openCamera() async {
        cameraMessage = nil; denied = false
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraMessage = "No camera available. Paste a connection link."; return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var allowed = status == .authorized
        if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        if allowed { showScanner = true }
        else {
            denied = status != .restricted
            cameraMessage = "Allow camera access or paste a link."
        }
    }
}
struct ElderReadyPage: View {
    let profile: ElderProfile
    var body: some View {
        PageLayout(step: "", title: "Connected") {
            Card {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundStyle(OrbitStyle.teal).frame(maxWidth: .infinity).padding(.vertical, 20)
                Text(profile.callName.isEmpty ? profile.name : profile.callName).font(.title.bold()).frame(maxWidth: .infinity)
            }
        }
    }
}
