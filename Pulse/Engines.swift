import Foundation

// MARK: - Recovery (reverse-engineered from WHOOP's published methodology)
//
// WHOOP's recovery is dominated by overnight HRV compared against a personal
// ~30-day baseline, secondarily resting HR, then sleep performance.
// We reproduce that as: z-score of today's value vs. baseline, squashed
// through a sigmoid into 0–100, weighted 50/25/25.

enum RecoveryEngine {

    static func baseline(from days: [DailyMetrics]) -> Baseline {
        let hrvs = days.compactMap(\.hrvSDNN)
        let rhrs = days.compactMap(\.restingHR)
        let sleeps = days.compactMap { $0.sleep?.totalHours }
        return Baseline(
            hrvMean: mean(hrvs, fallback: 50),
            hrvStd: max(std(hrvs), 5),
            rhrMean: mean(rhrs, fallback: 60),
            rhrStd: max(std(rhrs), 2),
            avgSleepNeedHours: max(mean(sleeps, fallback: 8), 7)
        )
    }

    static func score(today: DailyMetrics, baseline: Baseline) -> RecoveryResult {
        // HRV above baseline = good. Map z-score → 0–100.
        let hrvZ = ((today.hrvSDNN ?? baseline.hrvMean) - baseline.hrvMean) / baseline.hrvStd
        let hrvScore = sigmoid100(hrvZ)

        // RHR below baseline = good (inverted).
        let rhrZ = (baseline.rhrMean - (today.restingHR ?? baseline.rhrMean)) / baseline.rhrStd
        let rhrScore = sigmoid100(rhrZ)

        // Sleep performance: hours achieved vs. personal need, capped at 100.
        let sleepHours = today.sleep?.totalHours ?? 0
        let sleepScore = min(sleepHours / baseline.avgSleepNeedHours, 1.0) * 100

        let score = Int((0.50 * hrvScore + 0.25 * rhrScore + 0.25 * sleepScore).rounded())
        let zone: RecoveryZone = score < 34 ? .red : (score < 67 ? .yellow : .green)

        var parts: [String] = []
        if hrvZ > 0.5 { parts.append("HRV above your baseline") }
        if hrvZ < -0.5 { parts.append("HRV below your baseline") }
        if rhrZ < -0.5 { parts.append("resting HR elevated") }
        if sleepScore < 70 { parts.append("short on sleep") }
        let explanation = parts.isEmpty ? "In line with your normal range."
                                        : parts.joined(separator: ", ").capitalizedFirst + "."

        return RecoveryResult(score: score, hrvScore: hrvScore, rhrScore: rhrScore,
                              sleepScore: sleepScore, zone: zone, explanation: explanation)
    }

    private static func sigmoid100(_ z: Double) -> Double { 100 / (1 + exp(-1.2 * z)) }
    private static func mean(_ xs: [Double], fallback: Double) -> Double {
        xs.isEmpty ? fallback : xs.reduce(0, +) / Double(xs.count)
    }
    private static func std(_ xs: [Double]) -> Double {
        guard xs.count > 1 else { return 0 }
        let m = xs.reduce(0, +) / Double(xs.count)
        return sqrt(xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count - 1))
    }
}

// MARK: - Strain (reverse-engineered)
//
// WHOOP strain is a logarithmic 0–21 score of cardiovascular load: time spent
// in heart-rate zones (as % of heart-rate reserve), weighted so higher zones
// count exponentially more, then log-compressed so going 10→15 is much harder
// than 5→10. We reproduce: load = Σ minutes×zoneWeight, strain = 21·(1−e^(−load/τ)).

enum StrainEngine {

    static var maxHR: Double = 195   // ≈ 220 − age; make configurable in Settings later

    static func strain(heartRateSamples: [(date: Date, bpm: Double)], restingHR: Double) -> Double {
        guard heartRateSamples.count > 1 else { return 0 }
        let hrr = max(maxHR - restingHR, 60)

        var load = 0.0
        for i in 1..<heartRateSamples.count {
            let dtMin = min(heartRateSamples[i].date.timeIntervalSince(heartRateSamples[i-1].date) / 60, 10)
            let pctReserve = (heartRateSamples[i].bpm - restingHR) / hrr
            load += dtMin * zoneWeight(pctReserve)
        }
        return 21 * (1 - exp(-load / 90))
    }

    /// Exponential zone weighting: sitting ≈ 0, zone 5 counts ~16× zone 1.
    private static func zoneWeight(_ pctReserve: Double) -> Double {
        switch pctReserve {
        case ..<0.30: return 0.02
        case ..<0.40: return 0.25
        case ..<0.50: return 0.5
        case ..<0.60: return 1.0
        case ..<0.70: return 2.0
        case ..<0.80: return 4.0
        case ..<0.90: return 8.0
        default:      return 16.0
        }
    }
}

// MARK: - Sleep need (reverse-engineered)
//
// WHOOP: tonight's need = personal baseline + portion of accumulated sleep
// debt + extra for today's strain. High-strain days add up to ~1 h of need.

enum SleepEngine {

    static func sleepNeed(baseline: Baseline, recentDays: [DailyMetrics], todayStrain: Double) -> Double {
        let need = baseline.avgSleepNeedHours

        // Sleep debt over the last 7 days; repay 30% of it tonight (WHOOP-style gradual repayment).
        let debt = recentDays.reduce(0.0) { acc, d in
            acc + max(need - (d.sleep?.totalHours ?? need), 0)
        }
        let debtRepayment = min(debt * 0.3, 1.5)

        // Strain adjustment: strain 21 → +1 h.
        let strainExtra = (todayStrain / 21) * 1.0

        return min(need + debtRepayment + strainExtra, 11)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
