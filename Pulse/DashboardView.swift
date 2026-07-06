import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let recovery = health.recovery {
                        RecoveryCard(recovery: recovery)
                    }
                    HStack(spacing: 16) {
                        StrainCard(strain: health.today?.strain ?? 0)
                        CaloriesCard(active: health.today?.activeCalories ?? 0,
                                     basal: health.today?.basalCalories ?? 0)
                    }
                    if let sleep = health.today?.sleep {
                        SleepCard(sleep: sleep, needTonight: health.sleepNeedTonight)
                    } else {
                        NoSleepCard(needTonight: health.sleepNeedTonight)
                    }
                    VitalsCard(metrics: health.today)
                    TrendChart(history: health.history)
                }
                .padding()
            }
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).day().month()))
            .refreshable { await health.refresh() }
            .task { await health.refresh() }
        }
    }
}

// MARK: - Cards

struct RecoveryCard: View {
    let recovery: RecoveryResult

    var color: Color {
        switch recovery.zone {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ScoreRing(progress: Double(recovery.score) / 100,
                      color: color,
                      centerTop: "\(recovery.score)%",
                      centerBottom: "RECOVERY")
                .frame(width: 180, height: 180)
            Text(recovery.zone.label)
                .font(.headline)
                .foregroundStyle(color)
            Text(recovery.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct StrainCard: View {
    let strain: Double

    var body: some View {
        VStack(spacing: 8) {
            ScoreRing(progress: strain / 21, color: .blue,
                      centerTop: String(format: "%.1f", strain),
                      centerBottom: "STRAIN")
                .frame(width: 100, height: 100)
            Text("of 21").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CaloriesCard: View {
    let active: Double
    let basal: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill").font(.title).foregroundStyle(.orange)
            Text("\(Int(active + basal))").font(.title2.bold())
            Text("kcal total").font(.caption).foregroundStyle(.secondary)
            Text("\(Int(active)) active").font(.caption2).foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SleepCard: View {
    let sleep: SleepSummary
    let needTonight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Last night", systemImage: "moon.zzz.fill")
                .font(.headline)
            HStack {
                stat(hours: sleep.totalHours, label: "Asleep")
                stat(hours: sleep.deepSeconds / 3600, label: "Deep")
                stat(hours: sleep.remSeconds / 3600, label: "REM")
                stat(value: "\(Int(sleep.efficiency * 100))%", label: "Efficiency")
            }
            Divider()
            Label(String(format: "Aim for %.1f h tonight", needTonight),
                  systemImage: "bed.double.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    func stat(hours: Double, label: String) -> some View {
        stat(value: String(format: "%dh %02dm", Int(hours), Int(hours.truncatingRemainder(dividingBy: 1) * 60)), label: label)
    }
    func stat(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NoSleepCard: View {
    let needTonight: Double
    var body: some View {
        Label(String(format: "No sleep data yet — wear your watch tonight. Aim for %.1f h.", needTonight),
              systemImage: "moon.zzz")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct VitalsCard: View {
    let metrics: DailyMetrics?

    var body: some View {
        HStack {
            vital(icon: "waveform.path.ecg", color: .green,
                  value: metrics?.hrvSDNN.map { "\(Int($0)) ms" } ?? "—", label: "HRV")
            vital(icon: "heart.fill", color: .red,
                  value: metrics?.restingHR.map { "\(Int($0)) bpm" } ?? "—", label: "Resting HR")
            vital(icon: "lungs.fill", color: .cyan,
                  value: metrics?.respiratoryRate.map { String(format: "%.1f /min", $0) } ?? "—", label: "Resp. rate")
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    func vital(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ring + trend chart

struct ScoreRing: View {
    let progress: Double
    let color: Color
    let centerTop: String
    let centerBottom: String

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.002))
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)
            VStack(spacing: 2) {
                Text(centerTop).font(.system(size: 34, weight: .bold, design: .rounded))
                Text(centerBottom).font(.caption2.bold()).foregroundStyle(.secondary)
            }
        }
    }
}

struct TrendChart: View {
    let history: [DailyMetrics]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Strain — last 14 days", systemImage: "chart.bar.fill")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(history.suffix(14).enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.blue.gradient)
                            .frame(height: max(day.strain / 21 * 80, 2))
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
