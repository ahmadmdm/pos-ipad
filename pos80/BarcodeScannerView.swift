// BarcodeScannerView.swift — Camera-based barcode scanner + manual entry for iPad
import SwiftUI
import AVFoundation

// MARK: - Scanner Sheet (combines camera + manual input)
struct BarcodeScannerSheet: View {
    @Environment(POSViewModel.self) var vm
    @Environment(\.dismiss) var dismiss
    @State private var manualInput = ""
    @State private var scannedCode: String?
    @State private var cameraAvailable = false

    var body: some View {
        SheetContainer(title: "Scan Barcode") {
            VStack(spacing: 20) {
                // Camera scanner
                if cameraAvailable {
                    ZStack {
                        CameraBarcodeScanner { code in
                            scannedCode = code
                            Task {
                                await vm.lookupBarcode(code)
                                dismiss()
                            }
                        }
                        .frame(height: 280)
                        .cornerRadius(AppTheme.r16)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.r16)
                                .strokeBorder(AppTheme.accent.opacity(0.4), lineWidth: 2)
                        )

                        // Scan line animation
                        VStack {
                            Rectangle()
                                .fill(AppTheme.accent.opacity(0.6))
                                .frame(height: 2)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.textMuted)
                        Text("Camera not available")
                            .font(AppTheme.body())
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Use manual entry below")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r16)
                }

                // Divider with OR
                HStack {
                    Rectangle().fill(AppTheme.border).frame(height: 1)
                    Text("OR")
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 12)
                    Rectangle().fill(AppTheme.border).frame(height: 1)
                }

                // Manual barcode entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Barcode Manually")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(spacing: 10) {
                        ThemeTextField(
                            icon: "barcode",
                            placeholder: "Barcode number...",
                            text: $manualInput,
                            keyboardType: .numberPad
                        )

                        Button {
                            guard !manualInput.isEmpty else { return }
                            Task {
                                await vm.lookupBarcode(manualInput)
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(AppTheme.accentGrad)
                                .cornerRadius(AppTheme.r12)
                        }
                    }
                }

                if let code = scannedCode {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Scanned: \(code)")
                            .font(AppTheme.mono(13))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(12)
                    .background(AppTheme.success.opacity(0.1))
                    .cornerRadius(AppTheme.r8)
                }
            }
            .padding(24)
        }
        .onAppear {
            checkCameraAccess()
        }
    }

    private func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAvailable = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { cameraAvailable = granted }
            }
        default:
            cameraAvailable = false
        }
    }
}

// MARK: - Camera Barcode Scanner (AVFoundation)
struct CameraBarcodeScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .upce, .code128, .code39, .code93,
            .interleaved2of5, .itf14, .pdf417, .qr, .dataMatrix
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        self.captureSession = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadata.stringValue else { return }

        hasScanned = true
        captureSession?.stopRunning()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onScan?(code)
    }
}
