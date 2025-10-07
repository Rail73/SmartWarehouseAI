//
//  QRCodeView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct QRCodeView: View {
    let qrType: QRManager.QRCodeType
    let title: String

    @State private var qrImage: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .padding(.top)

            if let qrImage = qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            } else {
                ProgressView()
                    .frame(width: 300, height: 300)
            }

            Text("Scan this code to view details")
                .font(.caption)
                .foregroundColor(.secondary)

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(qrImage == nil)

                Button {
                    if let qrImage = qrImage {
                        saveToPhotos(qrImage)
                    }
                } label: {
                    Label("Save to Photos", systemImage: "photo")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .disabled(qrImage == nil)

                if case .item = qrType {
                    Button {
                        if let qrImage = qrImage {
                            printQRCode(qrImage)
                        }
                    } label: {
                        Label("Print Label", systemImage: "printer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    .disabled(qrImage == nil)
                } else if case .warehouse = qrType {
                    Button {
                        if let qrImage = qrImage {
                            printQRCode(qrImage)
                        }
                    } label: {
                        Label("Print Label", systemImage: "printer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    .disabled(qrImage == nil)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .onAppear {
            generateQRCode()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let qrImage = qrImage {
                ShareSheet(items: [qrImage])
            }
        }
    }

    private func generateQRCode() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = QRManager.shared.generateQRCode(for: qrType)
            DispatchQueue.main.async {
                self.qrImage = image
            }
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    private func printQRCode(_ image: UIImage) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "QR Code"

        printController.printInfo = printInfo
        printController.printingItem = image
        printController.present(animated: true)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView(
            qrType: .item(123),
            title: "Item QR Code"
        )
    }
}
