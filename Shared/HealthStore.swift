import Combine
import Foundation
import HealthKit
import StressCore
import WidgetKit

@MainActor
final class HealthStore: ObservableObject {
    @Published private(set) var snapshot = SnapshotCache.read()
    @Published private(set) var busy = false
    @Published private(set) var message: String?

    private let health = HKHealthStore()
    private let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

    func requestAccess() async {
        guard !busy else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "此设备无法读取健康数据。"
            return
        }
        busy = true
        message = nil
        do {
            // A successful request does not reveal whether read access was granted.
            try await health.requestAuthorization(toShare: [], read: [hrvType, heartRateType])
        } catch {
            message = "健康授权请求失败：\(error.localizedDescription)"
            busy = false
            return
        }
        busy = false
        await refresh()
    }

    func refresh() async {
        guard !busy else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "此设备无法读取健康数据。"
            return
        }
        busy = true
        message = nil
        defer { busy = false }

        do {
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -21, to: now)!
            let hrv = try await samples(type: hrvType, start: start, end: now)
            let heartRate = try await samples(
                type: heartRateType, start: now.addingTimeInterval(-7_200), end: now, limit: 1
            ).first
            let readings = hrv.map {
                HRVReading(date: $0.endDate, milliseconds: $0.quantity.doubleValue(for: .secondUnit(with: .milli)))
            }
            // HealthKit is the data source; third-party HRV samples are not silently excluded.
            let updated = StressEstimator.makeSnapshot(
                readings: readings, now: now,
                heartRate: heartRate?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                heartRateAt: heartRate?.endDate
            )
            snapshot = updated
            if readings.isEmpty {
                message = "没有可读取的 HRV 样本。可能尚未授权，或手表还没有生成／同步数据。"
            }
            do {
                try SnapshotCache.write(updated)
                WidgetCenter.shared.reloadTimelines(ofKind: "WatchStressComplication")
            } catch {
                message = [message, error.localizedDescription].compactMap { $0 }.joined(separator: "\n")
            }
        } catch {
            // Old cached samples remain visibly timestamped and expire automatically.
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func samples(
        type: HKQuantityType, start: Date, end: Date, limit: Int = HKObjectQueryNoLimit
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? [HKQuantitySample] ?? [])
                }
            }
            health.execute(query)
        }
    }
}

