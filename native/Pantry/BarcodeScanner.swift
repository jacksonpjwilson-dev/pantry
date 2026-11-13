import SwiftUI
import VisionKit
import AVFoundation

struct BarcodeScanner: View {
    var onResult: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var manual = ""
    @State private var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var cameraError: String?
    var body: some View {
        NavigationStack {
            VStack {
                if authorization == .authorized && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerCamera(onResult: onResult, onError: { cameraError = $0 }).clipShape(RoundedRectangle(cornerRadius: 20))
                } else { ContentUnavailableView("Camera scanning unavailable", systemImage: "barcode", description: Text("Enter the printed barcode below.")) }
                if authorization == .denied || authorization == .restricted {
                    Text("Camera access is off. You can enter a barcode or enable Camera in Settings.").font(.caption)
                    Link("Open iPhone Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                if let cameraError { Text(cameraError).font(.caption) }
                TextField("UPC or EAN barcode", text: $manual).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Button("Use barcode") { onResult(manual) }.disabled(manual.isEmpty || !manual.allSatisfy(\.isNumber))
                Text("Unknown barcodes open a blank item. Product details are never guessed.").font(.caption).foregroundStyle(.secondary)
            }.padding().navigationTitle("Scan a product").toolbar { Button("Cancel") { dismiss() } }
        }.onChange(of: scenePhase) { _, phase in
            if phase == .active { authorization = AVCaptureDevice.authorizationStatus(for: .video) }
        }.task {
            if authorization == .notDetermined && DataScannerViewController.isSupported {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                authorization = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}
private struct ScannerCamera: UIViewControllerRepresentable {
    var onResult: (String) -> Void
    var onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onResult) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() } catch { DispatchQueue.main.async { onError("Camera could not start. Enter the barcode below or try again.") } }
        return scanner
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { controller.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let result: (String) -> Void
        var delivered = false
        init(_ result: @escaping (String) -> Void) { self.result = result }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems { if case .barcode(let barcode) = item, let code = barcode.payloadStringValue, !delivered { delivered = true; dataScanner.stopScanning(); result(code); return } }
        }
    }
}
