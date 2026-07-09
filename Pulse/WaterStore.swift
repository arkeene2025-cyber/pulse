import Foundation
import WidgetKit

/// Shared water-intake store. Uses an App Group so the app and the
/// lock-screen widget read/write the same counter.
enum WaterStore {
    static let glassML = 250
    static let dailyGoalML = 4000
    static var goalGlasses: Int { dailyGoalML / glassML }   // 16

    static let appGroupID = "group.com.aarya.pulse"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "water-" + f.string(from: Date())
    }

    static var todayGlasses: Int {
        defaults.integer(forKey: todayKey)
    }

    static var todayML: Int { todayGlasses * glassML }

    static func addGlass() {
        defaults.set(todayGlasses + 1, forKey: todayKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func removeGlass() {
        defaults.set(max(todayGlasses - 1, 0), forKey: todayKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
