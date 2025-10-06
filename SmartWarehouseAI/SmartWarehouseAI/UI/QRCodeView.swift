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
            HStack(spacing: 20) {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(qrImage == nil)
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
