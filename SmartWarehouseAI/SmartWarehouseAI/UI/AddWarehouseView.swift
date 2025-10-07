//
//  AddWarehouseView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct AddWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var showError = false
    @State private var errorMessage = ""

    let onSave: (Warehouse) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Warehouse Name", text: $name)
                        .autocapitalization(.words)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                } header: {
                    Text("Warehouse Information")
                } footer: {
                    Text("Enter a name and optional description for the new warehouse.")
                }

                Section {
                    Button {
                        saveWarehouse()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save Warehouse")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Add Warehouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveWarehouse() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Warehouse name cannot be empty"
            showError = true
            return
        }

        let warehouse = Warehouse(
            name: trimmedName,
            warehouseDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
            createdAt: Date(),
            updatedAt: Date()
        )

        onSave(warehouse)
        dismiss()
    }
}

// MARK: - Preview

struct AddWarehouseView_Previews: PreviewProvider {
    static var previews: some View {
        AddWarehouseView { warehouse in
            print("Saved: \(warehouse.name)")
        }
    }
}
