import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var today: DailyMetrics?
    @Published var recovery: RecoveryResult?
    @Published var sleepNeedTonight: Double = 8.0
    @Published var history: [DailyMetrics] = []   // last 30 days, oldest first

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType()
    ]

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refresh()
        } catch {
            print("HealthKit auth failed: \(error)")
        }
    }

    func refresh() async {
        let cal = Calendar.current
        let dayStarts = stride(from: 29, through: 0, by: -1).map { offset in
            cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
        }

        // Fetch all 30 days concurrently instead of one at a time —
        // sequential fetches made the dashboard look frozen on first launch.
        let days: [DailyMetrics] = await withTaskGroup(of: (Int, DailyMetrics).self) { group in
            for (index, day) in dayStarts.enumerated() {
                group.addTask { (index, await self.metrics(for: day)) }
            }
            var results = [DailyMetrics?](repeating: nil, count: dayStarts.count)
            for await (index, metrics) in group {
                results[index] = metrics
            }
            return results.compactMap { $0 }
        }

        history = days
        today = days.last

        let baseline = RecoveryEngine.baseline(from: Array(days.dropLast()))
        if let today = today {
            recovery = RecoveryEngine.score(today: today, baseline: baseline)
            sleepNeedTonight = SleepEngine.sleepNeed(
                baseline: baseline,
                recentDays: Array(days.suffix(7)),
                todayStrain: today.strain
            )
        }
    }

    // MARK: - Per-day metric assembly

    private func metrics(for day: Date) async -> DailyMetrics {
        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!
        // Sleep window: 6pm previous day → noon today, catches any normal sleep pattern.
        let sleepWindowStart = cal.date(byAdding: .hour, value: -6, to: day)!
        let sleepWindowEnd = cal.date(byAdding: .hour, value: 12, to: day)!

        let sleep = await fetchSleep(from: sleepWindowStart, to: sleepWindowEnd)

        // Overnight HRV: samples during the sleep window only (matches WHOOP's approach).
        let hrvWindowStart = sleep?.inBedStart ?? sleepWindowStart
        let hrvWindowEnd = sleep?.inBedEnd ?? sleepWindowEnd
        let hrv = await averageQuantity(.heartRateVariabilitySDNN,
                                        unit: HKUnit.secondUnit(with: .milli),
                                        from: hrvWindowStart, to: hrvWindowEnd)
        let rhr = await averageQuantity(.restingHeartRate,
                                        unit: HKUnit.count().unitDivided(by: .minute()),
                                        from: day, to: dayEnd)
        let resp = await averageQuantity(.respiratoryRate,
                                         unit: HKUnit.count().unitDivided(by: .minute()),
                                         from: hrvWindowStart, to: hrvWindowEnd)
        let active = await sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: day, to: dayEnd)
        let basal = await sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), from: day, to: dayEnd)

        let hrSamples = await heartRateSamples(from: day, to: dayEnd)
        let strain = StrainEngine.strain(heartRateSamples: hrSamples, restingHR: rhr ?? 60)

        return DailyMetrics(date: day, hrvSDNN: hrv, restingHR: rhr,
                            respiratoryRate: resp, sleep: sleep,
                            activeCalories: active, basalCalories: basal, strain: strain)
    }

    // MARK: - HealthKit query helpers

    private func averageQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                                 from: Date, to: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKStatisticsQuery(quantityType: HKQuantityType(id),
                                          quantitySamplePredicate: predicate,
                                          options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                             from: Date, to: Date) async -> Double {
        await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKStatisticsQuery(quantityType: HKQuantityType(id),
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func heartRateSamples(from: Date, to: Date) async -> [(date: Date, bpm: Double)] {
        await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: HKQuantityType(.heartRate),
                                      predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { _, samples, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let result = (samples as? [HKQuantitySample])?.map {
                    (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                } ?? []
                cont.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func fetchSleep(from: Date, to: Date) async -> SleepSummary? {
        await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis),
                                      predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    cont.resume(returning: nil); return
                }
                // Prefer the watch's own stage data.
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let sleepSamples = samples.filter { asleepValues.contains($0.value) }
                guard !sleepSamples.isEmpty else { cont.resume(returning: nil); return }

                func total(_ value: HKCategoryValueSleepAnalysis) -> TimeInterval {
                    samples.filter { $0.value == value.rawValue }
                        .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                }

                let summary = SleepSummary(
                    inBedStart: sleepSamples.first!.startDate,
                    inBedEnd: sleepSamples.last!.endDate,
                    asleepSeconds: sleepSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) },
                    deepSeconds: total(.asleepDeep),
                    remSeconds: total(.asleepREM),
                    coreSeconds: total(.asleepCore),
                    awakeSeconds: total(.awake)
                )
                cont.resume(returning: summary)
            }
            store.execute(query)
        }
    }
}
