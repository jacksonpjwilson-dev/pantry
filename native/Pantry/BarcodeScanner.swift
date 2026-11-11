import SwiftUI
import VisionKit

struct BarcodeScanner: View {
    var onResult: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var manual = ""
    var body: some View {
        NavigationStack {
            VStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerCamera(onResult: onResult).clipShape(RoundedRectangle(cornerRadius: 20))
                } else { ContentUnavailableView("Camera scanning unavailable", systemImage: "barcode", description: Text("Enter the printed barcode below.")) }
                TextField("UPC or EAN barcode", text: $manual).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Button("Use barcode") { onResult(manual) }.disabled(manual.isEmpty || !manual.allSatisfy(\.isNumber))
                Text("Unknown barcodes open a blank item. Product details are never guessed.").font(.caption).foregroundStyle(.secondary)
            }.padding().navigationTitle("Scan a product").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
private struct ScannerCamera: UIViewControllerRepresentable {
    var onResult: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onResult) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() } catch { /* Manual entry remains available if permission is denied. */ }
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
