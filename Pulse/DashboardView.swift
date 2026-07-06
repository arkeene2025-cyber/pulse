import SwiftUI

// MARK: - Theme

enum Theme {
    static let bg = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let card = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let green = Color(red: 0.20, green: 0.92, blue: 0.55)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let red = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let blue = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let purple = Color(red: 0.70, green: 0.55, blue: 1.0)
}

extension View {
    func card() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Root tabs

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        TabView {
            TodayTab()
                .tabItem { Label("Today", systemImage: "circle.circle.fill") }
            SleepTab()
                .tabItem { Label("Sleep", systemImage: "moon.zzz.fill") }
            FoodTab()
                .tabItem { Label("Food", systemImage: "fork.knife") }
            TrendsTab()
                .tabItem { Label("Trends", systemImage: "chart.bar.fill") }
        }
        .tint(Theme.green)
        .preferredColorScheme(.dark)
        .task { await health.refresh() }
    }
}

// MARK: - TODAY

struct TodayTab: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let recovery = health.recovery {
                        RecoveryHero(recovery: recovery)
                    }
                    StrainSection(strain: health.today?.strain ?? 0,
                                  recovery: health.recovery)
                    CaloriesSection(active: health.today?.activeCalories ?? 0,
                                    basal: health.today?.basalCalories ?? 0)
                    VitalsSection(metrics: health.today)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.bg)
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).day().month()))
            .refreshable { await health.refresh() }
        }
    }
}

struct RecoveryHero: View {
    let recovery: RecoveryResult

    var color: Color {
        switch recovery.zone {
        case .red: return Theme.red
        case .yellow: return Theme.yellow
        case .green: return Theme.green
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("RECOVERY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(2)

            ZStack {
                Circle().stroke(color.opacity(0.12), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: max(Double(recovery.score) / 100, 0.01))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: recovery.score)
                VStack(spacing: 0) {
                    Text("\(recovery.score)%")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                    Text(recovery.zone.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.vertical, 6)

            Text(recovery.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider().overlay(Color.white.opacity(0.1))

            Text(advice)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    var advice: String {
        switch recovery.zone {
        case .green: return "💪 Your body is ready. A hard workout today is well-timed."
        case .yellow: return "⚖️ Go moderate today — a normal workout is fine, avoid max effort."
        case .red: return "🛌 Your body is still repairing. Rest or light movement only."
        }
    }
}

struct StrainSection: View {
    let strain: Double
    let recovery: RecoveryResult?

    var target: ClosedRange<Double> {
        switch recovery?.zone {
        case .green: return 14...18
        case .yellow: return 9...13
        case .red, .none: return 0...8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Strain", systemImage: "flame")
                    .font(.headline)
                    .foregroundStyle(Theme.blue)
                Spacer()
                Text(String(format: "%.1f", strain))
                    .font(.title2.bold())
                + Text(" / 21").font(.footnote).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 12)
                    Capsule().fill(Theme.green.opacity(0.25))
                        .frame(width: geo.size.width * (target.upperBound - target.lowerBound) / 21, height: 12)
                        .offset(x: geo.size.width * target.lowerBound / 21)
                    Capsule().fill(Theme.blue.gradient)
                        .frame(width: max(geo.size.width * strain / 21, 8), height: 12)
                }
            }
            .frame(height: 12)

            Text("How hard your heart worked today. Green band = today's sweet spot based on your recovery (\(Int(target.lowerBound))–\(Int(target.upperBound))).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

struct CaloriesSection: View {
    let active: Double
    let basal: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Calories burned", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("\(Int(active + basal))")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                Text("kcal today").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("\(Int(active)) active").font(.footnote)
                }
                HStack(spacing: 6) {
                    Circle().fill(.gray).frame(width: 8, height: 8)
                    Text("\(Int(basal)) resting").font(.footnote)
                }
                Text("Resting = what your body\nburns just being alive")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .card()
    }
}

struct VitalsSection: View {
    let metrics: DailyMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vitals — last night")
                .font(.headline)
            HStack(spacing: 10) {
                vital(icon: "waveform.path.ecg", color: Theme.green,
                      value: metrics?.hrvSDNN.map { "\(Int($0))" } ?? "—", unit: "ms", label: "HRV")
                vital(icon: "heart.fill", color: Theme.red,
                      value: metrics?.restingHR.map { "\(Int($0))" } ?? "—", unit: "bpm", label: "Resting HR")
                vital(icon: "lungs.fill", color: Theme.blue,
                      value: metrics?.respiratoryRate.map { String(format: "%.1f", $0) } ?? "—", unit: "/min", label: "Breathing")
            }
            Text("Higher HRV and lower resting heart rate than your normal = well recovered.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }

    func vital(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            (Text(value).font(.title3.bold()) + Text(" \(unit)").font(.caption2).foregroundStyle(.secondary))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - SLEEP

struct SleepTab: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let sleep = health.today?.sleep {
                        SleepScoreCard(sleep: sleep, need: health.sleepNeedTonight)
                        SleepStagesCard(sleep: sleep)
                    } else {
                        Text("No sleep recorded last night.\nWear your watch to bed tonight — that's when the magic starts. 🌙")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                    TonightCard(need: health.sleepNeedTonight)
                }
                .padding(.horizontal)
            }
            .background(Theme.bg)
            .navigationTitle("Sleep")
            .refreshable { await health.refresh() }
        }
    }
}

struct SleepScoreCard: View {
    let sleep: SleepSummary
    let need: Double

    var performance: Double { min(sleep.totalHours / need, 1.0) }

    var body: some View {
        VStack(spacing: 12) {
            Text("SLEEP PERFORMANCE")
                .font(.caption.bold()).foregroundStyle(.secondary).tracking(2)
            ZStack {
                Circle().stroke(Theme.purple.opacity(0.12), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(performance, 0.01))
                    .stroke(Theme.purple.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(performance * 100))%")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                    Text(hm(sleep.totalHours) + " slept")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            Text("You slept \(hm(sleep.totalHours)) of the \(hm(need)) your body needed.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct SleepStagesCard: View {
    let sleep: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep stages").font(.headline)

            stageBar

            stage(color: Theme.purple, name: "Deep", seconds: sleep.deepSeconds,
                  note: "Physical repair — muscles rebuild here")
            stage(color: Theme.blue, name: "REM", seconds: sleep.remSeconds,
                  note: "Mental recovery — memory and learning")
            stage(color: .gray, name: "Core (light)", seconds: sleep.coreSeconds,
                  note: "Normal light sleep between cycles")
            stage(color: Theme.red.opacity(0.7), name: "Awake", seconds: sleep.awakeSeconds,
                  note: "Brief wake-ups are completely normal")

            Divider().overlay(Color.white.opacity(0.1))
            HStack {
                Text("Efficiency \(Int(sleep.efficiency * 100))%")
                Spacer()
                Text("Restorative \(String(format: "%.1f", sleep.restorativeHours)) h")
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }

    var stageBar: some View {
        GeometryReader { geo in
            let total = max(sleep.deepSeconds + sleep.remSeconds + sleep.coreSeconds + sleep.awakeSeconds, 1)
            HStack(spacing: 2) {
                Rectangle().fill(Theme.purple).frame(width: geo.size.width * sleep.deepSeconds / total)
                Rectangle().fill(Theme.blue).frame(width: geo.size.width * sleep.remSeconds / total)
                Rectangle().fill(Color.gray).frame(width: geo.size.width * sleep.coreSeconds / total)
                Rectangle().fill(Theme.red.opacity(0.7)).frame(width: geo.size.width * sleep.awakeSeconds / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 14)
    }

    func stage(color: Color, name: String, seconds: TimeInterval, note: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline.bold())
                Text(note).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(hm(seconds / 3600)).font(.subheadline.monospacedDigit())
        }
    }
}

struct TonightCard: View {
    let need: Double

    var bedtime: String {
        // Suggest bedtime for a 6:30 wake-up as a friendly default.
        let wake = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date().addingTimeInterval(86400))!
        let bed = wake.addingTimeInterval(-need * 3600)
        return bed.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tonight's target", systemImage: "bed.double.fill")
                .font(.headline).foregroundStyle(Theme.purple)
            Text(hm(need))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
            Text("Based on your baseline, sleep debt and today's strain. For a 6:30 AM wake-up, be asleep by \(bedtime).")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }
}

// MARK: - TRENDS

struct TrendsTab: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TrendBars(title: "Strain — last 14 days", color: Theme.blue,
                              values: health.history.suffix(14).map { ($0.date, $0.strain, 21) },
                              footnote: "Watch for: several high-strain days in a row without green recoveries.")
                    TrendBars(title: "Sleep hours — last 14 days", color: Theme.purple,
                              values: health.history.suffix(14).map { ($0.date, $0.sleep?.totalHours ?? 0, 10) },
                              footnote: "Consistency beats duration — same bedtime daily improves recovery.")
                    TrendBars(title: "HRV — last 14 days", color: Theme.green,
                              values: health.history.suffix(14).map { ($0.date, $0.hrvSDNN ?? 0, (health.history.compactMap(\.hrvSDNN).max() ?? 100) * 1.2) },
                              footnote: "Rising trend over weeks = fitness improving. Sudden drop = stress, illness or overtraining.")
                }
                .padding(.horizontal)
            }
            .background(Theme.bg)
            .navigationTitle("Trends")
            .refreshable { await health.refresh() }
        }
    }
}

struct TrendBars: View {
    let title: String
    let color: Color
    let values: [(date: Date, value: Double, max: Double)]
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.gradient)
                            .frame(height: max(v.value / max(v.max, 1) * 90, 2))
                        Text(v.date.formatted(.dateTime.day()))
                            .font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110, alignment: .bottom)
            Text(footnote).font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }
}

// MARK: - Helpers

func hm(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return "\(h)h \(String(format: "%02d", m))m"
}
