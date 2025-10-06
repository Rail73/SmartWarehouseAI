//
//  BarcodeScannerManager.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import Foundation
import AVFoundation
import UIKit

/// Manages barcode and QR code scanning using AVFoundation
class BarcodeScannerManager: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var errorMessage: String?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var onCodeScanned: ((String) -> Void)?

    // MARK: - Permission Handling

    enum CameraPermission {
        case authorized
        case denied
        case notDetermined
    }

    func checkCameraPermission() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Scanner Setup

    func startScanning(in view: UIView, onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned

        guard checkCameraPermission() == .authorized else {
            errorMessage = "Camera access denied. Please enable in Settings."
            return
        }

        setupCaptureSession(in: view)
    }

    private func setupCaptureSession(in view: UIView) {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorMessage = "No camera device found"
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            errorMessage = "Failed to access camera: \(error.localizedDescription)"
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            errorMessage = "Could not add video input"
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

            // Support multiple barcode types
            metadataOutput.metadataObjectTypes = [
                .qr,
                .ean8,
                .ean13,
                .upce,
                .code39,
                .code93,
                .code128,
                .dataMatrix,
                .pdf417
            ]
        } else {
            errorMessage = "Could not add metadata output"
            return
        }

        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
        self.captureSession = session

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.isScanning = true
            }
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        captureSession = nil
        previewLayer = nil
        isScanning = false
    }

    // MARK: - Layout Update

    func updatePreviewLayerFrame(_ frame: CGRect) {
        previewLayer?.frame = frame
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerManager: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Haptic feedback
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        scannedCode = stringValue
        onCodeScanned?(stringValue)
    }
}
