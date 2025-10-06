import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingAbout = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $appSettings.isDarkMode)
                }

                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $appSettings.notificationsEnabled)
                }

                Section(header: Text("Backup")) {
                    Toggle("Auto Backup", isOn: $appSettings.autoBackup)

                    if appSettings.autoBackup {
                        Picker("Backup Frequency", selection: $appSettings.backupFrequency) {
                            ForEach(AppSettings.BackupFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                    }

                    Button("Backup Now") {
                        performBackup()
                    }

                    Button("Restore from Backup") {
                        restoreBackup()
                    }
                }

                Section(header: Text("Data")) {
                    Button("Export Data") {
                        exportData()
                    }

                    Button("Import Data") {
                        importData()
                    }
                }

                Section(header: Text("About")) {
                    Button("About SmartWarehouse AI") {
                        showingAbout = true
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .onChange(of: appSettings.isDarkMode) { _ in
                appSettings.saveSettings()
            }
            .onChange(of: appSettings.notificationsEnabled) { _ in
                appSettings.saveSettings()
            }
            .onChange(of: appSettings.autoBackup) { _ in
                appSettings.saveSettings()
            }
            .onChange(of: appSettings.backupFrequency) { _ in
                appSettings.saveSettings()
            }
        }
    }

    private func performBackup() {
        // Implement backup logic
    }

    private func restoreBackup() {
        // Implement restore logic
    }

    private func exportData() {
        // Implement export logic
    }

    private func importData() {
        // Implement import logic
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "cube.box.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                Text("SmartWarehouse AI")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0.0")
                    .foregroundColor(.secondary)

                Text("Intelligent warehouse management system")
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings())
    }
}
