//
//  PDFImportView.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFImportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PDFImportViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isProcessing {
                    processingView
                } else if let result = viewModel.importResult {
                    resultView(result)
                } else {
                    uploadView
                }
            }
            .padding()
            .navigationTitle("Import PDF Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .fileImporter(
                isPresented: $viewModel.showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await viewModel.handleFileSelection(result)
                }
            }
        }
    }

    // MARK: - Upload View

    private var uploadView: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text("Import Catalog from PDF")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Upload a PDF catalog to automatically extract items")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.showingFilePicker = true
            } label: {
                Label("Choose PDF File", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "checkmark.circle", text: "Supports structured PDFs with tables")
                InfoRow(icon: "checkmark.circle", text: "OCR for scanned catalogs")
                InfoRow(icon: "checkmark.circle", text: "Auto-detection of SKU and names")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Spacer()
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Processing PDF...")
                .font(.headline)

            if let status = viewModel.processingStatus {
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Result View

    private func resultView(_ result: CompleteImportResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: result.saveResult.successCount > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.saveResult.successCount > 0 ? .green : .orange)
                            .font(.title)

                        VStack(alignment: .leading) {
                            Text("Import Complete")
                                .font(.headline)
                            Text(result.sourceFile)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Stats
                    HStack(spacing: 30) {
                        StatItem(
                            title: "Imported",
                            value: "\(result.saveResult.successCount)",
                            color: .green
                        )

                        StatItem(
                            title: "Skipped",
                            value: "\(result.saveResult.skipCount)",
                            color: .orange
                        )

                        StatItem(
                            title: "Success",
                            value: "\(Int(result.saveResult.successRate * 100))%",
                            color: .blue
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Warnings
                if !result.parseResult.warnings.isEmpty {
                    WarningSection(warnings: result.parseResult.warnings)
                }

                // Errors
                if !result.parseResult.errors.isEmpty {
                    ErrorSection(errors: result.parseResult.errors)
                }

                // Skipped Items
                if !result.saveResult.skipped.isEmpty {
                    SkippedItemsSection(skipped: result.saveResult.skipped)
                }

                // Actions
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct WarningSection: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Warnings (\(warnings.count))", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)

            ForEach(warnings, id: \.self) { warning in
                Text("• \(warning)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ErrorSection: View {
    let errors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Errors (\(errors.count))", systemImage: "xmark.circle")
                .font(.headline)
                .foregroundColor(.red)

            ForEach(errors, id: \.self) { error in
                Text("• \(error)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SkippedItemsSection: View {
    let skipped: [(ParsedItem, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Skipped Items (\(skipped.count))", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)

            ForEach(Array(skipped.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Reason: \(item.1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                if index < skipped.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - View Model

@MainActor
class PDFImportViewModel: ObservableObject {
    @Published var showingFilePicker = false
    @Published var isProcessing = false
    @Published var processingStatus: String?
    @Published var importResult: CompleteImportResult?

    private let importService = PDFImportService()

    func handleFileSelection(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result,
              let url = urls.first else {
            return
        }

        isProcessing = true
        processingStatus = "Reading PDF..."

        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw PDFParserError.cannotOpenFile
            }
            defer { url.stopAccessingSecurityScopedResource() }

            processingStatus = "Parsing document..."

            let result = try await importService.importAndSave(from: url)

            importResult = result
            isProcessing = false

            print(result.summary)
        } catch {
            isProcessing = false
            processingStatus = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    PDFImportView()
}
