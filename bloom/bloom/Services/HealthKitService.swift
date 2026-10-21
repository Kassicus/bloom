import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// The data types Bloom reads and writes.
    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let t = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .ovulationTestResult) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .sexualActivity) { types.insert(t) }
        return types
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let t = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .ovulationTestResult) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .sexualActivity) { types.insert(t) }
        return types
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// True once the user has allowed Bloom to write menstrual data to Health. (HealthKit never
    /// reveals whether *read* access was granted, so this is the only status that can be checked.)
    var isSharingAuthorized: Bool {
        guard let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return false }
        return store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: - Mirroring

    /// Replaces everything Bloom previously wrote to Health (optionally only within a date range)
    /// with samples for `logs`. Running it again never creates duplicates, and data that was
    /// removed in Bloom is removed from Health too.
    func mirror(_ logs: [DailyLog], from start: Date? = nil, to end: Date? = nil) async throws {
        var predicates = [HKQuery.predicateForObjects(from: HKSource.default())]
        if let start, let end {
            predicates.append(HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        for type in shareTypes {
            // Fails for types the user didn't authorize; those are simply skipped.
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }

        let today = Date.now.startOfDay
        let samples = logs
            .filter { $0.date.startOfDay <= today }
            .flatMap(samples(for:))
        if !samples.isEmpty {
            try await store.save(samples)
        }
    }

    // MARK: - Automatic Sync

    private var pendingRange: (start: Date, end: Date)?
    private var syncTask: Task<Void, Never>?

    /// Mirrors the given days to Health shortly after edits stop (edits arrive in bursts, e.g.
    /// one per tap or keystroke). Does nothing unless Health sync is turned on.
    func scheduleSync(from start: Date, to end: Date, using cycleManager: CycleManager) {
        guard Preferences.healthKitEnabled, isAvailable else { return }

        let start = start.startOfDay
        let end = end.startOfDay
        if let pending = pendingRange {
            pendingRange = (min(pending.start, start), max(pending.end, end))
        } else {
            pendingRange = (start, end)
        }

        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let range = pendingRange else { return }
            pendingRange = nil
            let logs = Array(cycleManager.logsByDay(from: range.start, to: range.end).values)
            try? await mirror(logs, from: range.start, to: range.end)
        }
    }

    func scheduleSync(for day: Date, using cycleManager: CycleManager) {
        scheduleSync(from: day, to: day.startOfDay.addingDays(1), using: cycleManager)
    }

    // MARK: - Samples

    private func samples(for log: DailyLog) -> [HKSample] {
        let day = log.date.startOfDay
        let nextDay = day.addingDays(1)
        var samples: [HKSample] = []

        if log.isOnPeriod, let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) {
            let value: HKCategoryValueVaginalBleeding = switch log.flowIntensity {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .spotting, nil: .unspecified
            }
            let isCycleStart = log.cycle.map { $0.startDate.startOfDay == day } ?? false
            samples.append(HKCategorySample(
                type: type,
                value: value.rawValue,
                start: day,
                end: nextDay,
                metadata: [HKMetadataKeyMenstrualCycleStart: isCycleStart]
            ))
        }

        if let temperature = log.bbtTemperature,
           let type = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) {
            let quantity = HKQuantity(unit: .degreeFahrenheit(), doubleValue: temperature)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: day, end: day))
        }

        if let mucus = log.cervicalMucus,
           let type = HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality) {
            let value: HKCategoryValueCervicalMucusQuality = switch mucus {
            case .dry: .dry
            case .sticky: .sticky
            case .creamy: .creamy
            case .watery: .watery
            case .eggWhite: .eggWhite
            }
            samples.append(HKCategorySample(type: type, value: value.rawValue, start: day, end: nextDay))
        }

        if let opk = log.opkResult,
           let type = HKCategoryType.categoryType(forIdentifier: .ovulationTestResult) {
            let value: HKCategoryValueOvulationTestResult = switch opk {
            case .negative: .negative
            case .nearPositive: .indeterminate
            case .positive: .luteinizingHormoneSurge
            }
            samples.append(HKCategorySample(type: type, value: value.rawValue, start: day, end: nextDay))
        }

        if let type = HKCategoryType.categoryType(forIdentifier: .sexualActivity) {
            for entry in log.intercourseEntries ?? [] {
                samples.append(HKCategorySample(
                    type: type,
                    value: HKCategoryValue.notApplicable.rawValue,
                    start: entry.dateTime,
                    end: entry.dateTime
                ))
            }
        }

        return samples
    }
}
