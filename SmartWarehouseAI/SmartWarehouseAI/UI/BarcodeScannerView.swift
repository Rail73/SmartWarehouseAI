//
//  BarcodeScannerView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @StateObject private var scannerManager = BarcodeScannerManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingResult = false
    @State private var scanResult: ScanResult?

    let onCodeScanned: (String) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                CameraPreviewView(scannerManager: scannerManager) { code in
                    handleScannedCode(code)
                }
                .edgesIgnoringSafeArea(.all)

                // Scanning overlay
                VStack {
                    Spacer()

                    // Scanning frame
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 300, height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("Scan QR or Barcode")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        )

                    Spacer()

                    // Instructions
                    VStack(spacing: 8) {
                        Text("Point camera at a barcode or QR code")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Scanning will happen automatically")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.bottom, 40)
                }

                // Error message
                if let error = scannerManager.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        scannerManager.stopScanning()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingResult) {
                if let result = scanResult {
                    ScanResultView(result: result) {
                        scannerManager.stopScanning()
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkPermissionAndStartScanning()
            }
            .onDisappear {
                scannerManager.stopScanning()
            }
        }
    }

    private func checkPermissionAndStartScanning() {
        let permission = scannerManager.checkCameraPermission()

        switch permission {
        case .authorized:
            // Will start scanning when CameraPreviewView appears
            break
        case .notDetermined:
            scannerManager.requestCameraPermission { granted in
                if !granted {
                    scannerManager.errorMessage = "Camera access denied"
                }
            }
        case .denied:
            scannerManager.errorMessage = "Camera access denied. Please enable in Settings."
        }
    }

    private func handleScannedCode(_ code: String) {
        // Check if it's a QR code from our app
        if let qrData = QRManager.shared.parseQRCode(code) {
            scanResult = .qrCode(qrData)
        } else {
            // Regular barcode
            scanResult = .barcode(code)
        }

        showingResult = true
        onCodeScanned(code)
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var scannerManager: BarcodeScannerManager
    let onCodeScanned: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if !scannerManager.isScanning {
            scannerManager.startScanning(in: uiView, onCodeScanned: onCodeScanned)
        } else {
            scannerManager.updatePreviewLayerFrame(uiView.bounds)
        }
    }
}

// MARK: - Scan Result Types

enum ScanResult {
    case qrCode(QRManager.QRCodeData)
    case barcode(String)
}

// MARK: - Scan Result View

struct ScanResultView: View {
    let result: ScanResult
    let onDismiss: () -> Void

    @State private var navigateToItem: Int64?
    @State private var navigateToKit: Int64?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 80))
                    .foregroundColor(iconColor)
                    .padding(.top, 40)

                // Title
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    detailsView
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()

                // Action buttons
                actionButtons
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private var iconName: String {
        switch result {
        case .qrCode(let qrData):
            return qrData.isValid ? "checkmark.seal.fill" : "xmark.seal.fill"
        case .barcode:
            return "barcode.viewfinder"
        }
    }

    private var iconColor: Color {
        switch result {
        case .qrCode(let qrData):
            return qrData.isValid ? .green : .red
        case .barcode:
            return .blue
        }
    }

    private var titleText: String {
        switch result {
        case .qrCode(let qrData):
            return qrData.isValid ? "Valid QR Code" : "Invalid QR Code"
        case .barcode:
            return "Barcode Scanned"
        }
    }

    @ViewBuilder
    private var detailsView: some View {
        switch result {
        case .qrCode(let qrData):
            HStack {
                Text("Type:")
                    .fontWeight(.semibold)
                Spacer()
                switch qrData.type {
                case .item(let id):
                    Text("Item #\(id)")
                case .kit(let id):
                    Text("Kit #\(id)")
                }
            }

            HStack {
                Text("Signature:")
                    .fontWeight(.semibold)
                Spacer()
                Text(qrData.isValid ? "Valid ✓" : "Invalid ✗")
                    .foregroundColor(qrData.isValid ? .green : .red)
            }

        case .barcode(let code):
            HStack {
                Text("Code:")
                    .fontWeight(.semibold)
                Spacer()
                Text(code)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch result {
        case .qrCode(let qrData) where qrData.isValid:
            Button {
                switch qrData.type {
                case .item(let id):
                    navigateToItem = id
                case .kit(let id):
                    navigateToKit = id
                }
            } label: {
                Text("View Details")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }

        case .barcode(let code):
            Button {
                // Search for item by barcode
                // This will be implemented when integrating
                print("Search for barcode: \(code)")
            } label: {
                Text("Search in Inventory")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerView { code in
            print("Scanned: \(code)")
        }
    }
}
