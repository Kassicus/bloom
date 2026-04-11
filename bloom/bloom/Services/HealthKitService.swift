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

    // MARK: - Write to HealthKit

    func saveMenstrualFlow(date: Date, flow: FlowIntensity, isCycleStart: Bool) async throws {
        guard let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return }

        let hkValue: HKCategoryValueMenstrualFlow
        switch flow {
        case .spotting: hkValue = .unspecified
        case .light: hkValue = .light
        case .medium: hkValue = .medium
        case .heavy: hkValue = .heavy
        }

        let metadata: [String: Any] = [
            HKMetadataKeyMenstrualCycleStart: isCycleStart
        ]

        let sample = HKCategorySample(
            type: type,
            value: hkValue.rawValue,
            start: date.startOfDay,
            end: date.startOfDay.addingDays(1),
            metadata: metadata
        )

        try await store.save(sample)
    }

    func saveBBT(date: Date, temperatureFahrenheit: Double) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) else { return }

        let quantity = HKQuantity(unit: .degreeFahrenheit(), doubleValue: temperatureFahrenheit)
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date.startOfDay,
            end: date.startOfDay
        )

        try await store.save(sample)
    }

    func saveCervicalMucus(date: Date, mucus: CervicalMucusType) async throws {
        guard let type = HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality) else { return }

        let hkValue: HKCategoryValueCervicalMucusQuality
        switch mucus {
        case .dry: hkValue = .dry
        case .sticky: hkValue = .sticky
        case .creamy: hkValue = .creamy
        case .watery: hkValue = .watery
        case .eggWhite: hkValue = .eggWhite
        }

        let sample = HKCategorySample(
            type: type,
            value: hkValue.rawValue,
            start: date.startOfDay,
            end: date.startOfDay.addingDays(1)
        )

        try await store.save(sample)
    }

    func saveOPKResult(date: Date, result: OPKResult) async throws {
        guard let type = HKCategoryType.categoryType(forIdentifier: .ovulationTestResult) else { return }

        let hkValue: HKCategoryValueOvulationTestResult
        switch result {
        case .negative: hkValue = .negative
        case .nearPositive: hkValue = .indeterminate
        case .positive: hkValue = .positive
        }

        let sample = HKCategorySample(
            type: type,
            value: hkValue.rawValue,
            start: date.startOfDay,
            end: date.startOfDay.addingDays(1)
        )

        try await store.save(sample)
    }

    func saveSexualActivity(date: Date) async throws {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sexualActivity) else { return }

        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValue.notApplicable.rawValue,
            start: date,
            end: date
        )

        try await store.save(sample)
    }

    // MARK: - Sync a DailyLog

    func syncLog(_ log: DailyLog, isCycleStart: Bool = false) async {
        let date = log.date

        if log.isOnPeriod, let flow = log.flowIntensity {
            try? await saveMenstrualFlow(date: date, flow: flow, isCycleStart: isCycleStart)
        }

        if let temp = log.bbtTemperature {
            try? await saveBBT(date: date, temperatureFahrenheit: temp)
        }

        if let mucus = log.cervicalMucus {
            try? await saveCervicalMucus(date: date, mucus: mucus)
        }

        if let opk = log.opkResult {
            try? await saveOPKResult(date: date, result: opk)
        }

        for entry in log.intercourseEntries ?? [] {
            try? await saveSexualActivity(date: entry.dateTime)
        }
    }
}
