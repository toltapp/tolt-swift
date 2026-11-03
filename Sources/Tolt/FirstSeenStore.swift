import Foundation

struct FirstSeenStore {
    static let key = "com.tolt.first_seen_at"

    let defaults: UserDefaults

    func firstSeenAt(now: Date = Date()) -> Date {
        if let stored = defaults.object(forKey: Self.key) as? Date { return stored }
        defaults.set(now, forKey: Self.key)
        return now
    }
}
