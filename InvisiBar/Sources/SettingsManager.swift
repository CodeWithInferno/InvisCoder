import Foundation

struct AppSettings: Codable {
    var windowOriginX: Double?
    var windowOriginY: Double?
}

@MainActor
class SettingsManager {
    static let shared = SettingsManager()
    private let settingsURL: URL

    private init() {
        // Get the URL for the application support directory
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to find application support directory.")
        }
        
        // Create a directory for our app if it doesn't exist
        let appDirectoryURL = appSupportURL.appendingPathComponent("InvisiBar")
        if !FileManager.default.fileExists(atPath: appDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.settingsURL = appDirectoryURL.appendingPathComponent("settings.json")
    }

    func save(settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    func load() -> AppSettings? {
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            return settings
        } catch {
            // It's normal for this to fail if the file doesn't exist yet
            return nil
        }
    }
}
