import Foundation

struct DailyMetrics {
    var date: Date
    var hrvSDNN: Double?          // ms, overnight average
    var restingHR: Double?        // bpm
    var respiratoryRate: Double?  // breaths/min during sleep
    var sleep: SleepSummary?
    var activeCalories: Double
    var basalCalories: Double
    var strain: Double            // 0–21
}

struct SleepSummary {
    var inBedStart: Date
    var inBedEnd: Date
    var asleepSeconds: TimeInterval
    var deepSeconds: TimeInterval
    var remSeconds: TimeInterval
    var coreSeconds: TimeInterval
    var awakeSeconds: TimeInterval

    var totalHours: Double { asleepSeconds / 3600 }
    var efficiency: Double {
        let inBed = inBedEnd.timeIntervalSince(inBedStart)
        return inBed > 0 ? asleepSeconds / inBed : 0
    }
    /// Deep + REM = restorative sleep, the number WHOOP emphasizes.
    var restorativeHours: Double { (deepSeconds + remSeconds) / 3600 }
}

struct RecoveryResult {
    var score: Int                // 0–100
    var hrvScore: Double
    var rhrScore: Double
    var sleepScore: Double
    var zone: RecoveryZone
    var explanation: String
}

enum RecoveryZone {
    case red, yellow, green

    var label: String {
        switch self {
        case .red: return "Take it easy"
        case .yellow: return "Moderate day"
        case .green: return "Ready to push"
        }
    }
}

struct Baseline {
    var hrvMean: Double
    var hrvStd: Double
    var rhrMean: Double
    var rhrStd: Double
    var avgSleepNeedHours: Double
}
