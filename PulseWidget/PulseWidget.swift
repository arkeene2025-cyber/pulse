import WidgetKit
import SwiftUI
import AppIntents

// MARK: - The tap action: +1 glass (250 ml)

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a glass of water"
    static var description = IntentDescription("Adds one 250 ml glass to today's water intake.")

    func perform() async throws -> some IntentResult {
        WaterStore.addGlass()
        return .result()
    }
}

// MARK: - Timeline

struct WaterEntry: TimelineEntry {
    let date: Date
    let glasses: Int
}

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: Date(), glasses: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(WaterEntry(date: Date(), glasses: WaterStore.todayGlasses))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        let entry = WaterEntry(date: Date(), glasses: WaterStore.todayGlasses)
        // Refresh at midnight so the counter resets visually.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Widget views

struct WaterWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WaterEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock screen circle: tap = +1 glass
            Button(intent: LogWaterIntent()) {
                ZStack {
                    Gauge(value: Double(entry.glasses), in: 0...Double(WaterStore.goalGlasses)) {
                        Image(systemName: "drop.fill")
                    } currentValueLabel: {
                        VStack(spacing: 0) {
                            Image(systemName: "drop.fill").font(.caption2)
                            Text("\(entry.glasses)/\(WaterStore.goalGlasses)").font(.caption2.bold())
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                }
            }
            .buttonStyle(.plain)

        case .accessoryRectangular:
            // Lock screen rectangle: progress + tap target
            Button(intent: LogWaterIntent()) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.glasses * WaterStore.glassML) ml of \(WaterStore.dailyGoalML) ml")
                            .font(.caption.bold())
                        Gauge(value: Double(entry.glasses), in: 0...Double(WaterStore.goalGlasses)) { EmptyView() }
                            .gaugeStyle(.accessoryLinear)
                        Text("Tap to add a glass").font(.caption2)
                    }
                }
            }
            .buttonStyle(.plain)

        default:
            // Home screen small widget
            VStack(spacing: 8) {
                Gauge(value: Double(entry.glasses), in: 0...Double(WaterStore.goalGlasses)) {
                    Image(systemName: "drop.fill")
                } currentValueLabel: {
                    Text("\(entry.glasses)")
                        .font(.title2.bold())
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.cyan)
                .scaleEffect(1.2)

                Text("\(entry.glasses * WaterStore.glassML) / \(WaterStore.dailyGoalML) ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(intent: LogWaterIntent()) {
                    Label("+ Glass", systemImage: "drop.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding(4)
        }
    }
}

struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WaterWidget", provider: WaterProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water intake")
        .description("Tap the glass to log 250 ml. Goal: 4 litres a day.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

@main
struct PulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        WaterWidget()
    }
}
