import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var autoBackup: Bool = true
    @Published var backupFrequency: BackupFrequency = .daily

    enum BackupFrequency: String, CaseIterable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Load settings from UserDefaults
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        autoBackup = UserDefaults.standard.bool(forKey: "autoBackup")
        if let frequencyRaw = UserDefaults.standard.string(forKey: "backupFrequency"),
           let frequency = BackupFrequency(rawValue: frequencyRaw) {
            backupFrequency = frequency
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(autoBackup, forKey: "autoBackup")
        UserDefaults.standard.set(backupFrequency.rawValue, forKey: "backupFrequency")
    }
}
