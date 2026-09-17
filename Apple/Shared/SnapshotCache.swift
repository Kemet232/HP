import Foundation
import HPCore

/// One derived snapshot per device. Never a HealthKit history database.
enum SnapshotCache {
    static let group = "group.com.kemet.hp"
    static var location: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("today.json")
    }
    static func read() -> SnapshotEnvelope? {
        guard let url = location, let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(SnapshotEnvelope.self, from: data), envelope.schemaVersion == 1 else { return nil }
        return envelope
    }
    static func write(_ envelope: SnapshotEnvelope) throws {
        guard var url = location else { throw CacheError.missingAppGroup }
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
    enum CacheError: Error { case missingAppGroup }
}

// Preferences contain configuration only. Health values are never stored in UserDefaults.
enum PreferenceStore {
    private static let key = "hp.preferences.v1"
    static func read() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(Preferences.self, from: data),
              (try? value.goal.validated()) != nil else { return Preferences() }
        return value
    }
    static func write(_ value: Preferences) throws {
        try UserDefaults.standard.set(JSONEncoder().encode(value), forKey: key)
    }
}
