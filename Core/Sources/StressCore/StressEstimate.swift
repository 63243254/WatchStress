import Foundation

public struct HRVReading: Sendable {
    public let date: Date
    public let milliseconds: Double

    public init(date: Date, milliseconds: Double) {
        self.date = date
        self.milliseconds = milliseconds
    }
}

public struct StressSnapshot: Codable, Sendable {
    public let generatedAt: Date
    public let sampleAt: Date?
    public let hrvMilliseconds: Double?
    public let baselineMilliseconds: Double?
    public let baselineDays: Int
    public let score: Int?
    public let heartRate: Double?
    public let heartRateAt: Date?

    public static let maximumAge: TimeInterval = 2 * 60 * 60

    public var expiresAt: Date? {
        sampleAt?.addingTimeInterval(Self.maximumAge)
    }

    public func isStale(at now: Date) -> Bool {
        guard let sampleAt else { return true }
        let age = now.timeIntervalSince(sampleAt)
        return age < 0 || age >= Self.maximumAge
    }

    public func displayScore(at now: Date) -> Int? {
        isStale(at: now) ? nil : score
    }

    public func label(at now: Date) -> String {
        guard sampleAt != nil else { return "等待 HRV" }
        guard !isStale(at: now) else { return "数据较旧" }
        guard let score else { return "基线积累中" }
        switch score {
        case ..<35: return "偏放松"
        case ..<65: return "接近基线"
        case ..<80: return "偏紧张"
        default: return "负荷较高"
        }
    }

    public static func empty(at date: Date = Date()) -> StressSnapshot {
        StressSnapshot(
            generatedAt: date, sampleAt: nil, hrvMilliseconds: nil,
            baselineMilliseconds: nil, baselineDays: 0, score: nil,
            heartRate: nil, heartRateAt: nil
        )
    }
}

public enum StressEstimator {
    /// An unvalidated personal HRV comparison, not a diagnostic stress test.
    /// Daily medians give each baseline day equal weight. The latest sample's
    /// calendar day is excluded so it cannot contribute to its own baseline.
    public static func makeSnapshot(
        readings: [HRVReading],
        now: Date = Date(),
        calendar: Calendar = .current,
        heartRate: Double? = nil,
        heartRateAt: Date? = nil
    ) -> StressSnapshot {
        let valid = readings.filter {
            $0.date <= now && $0.milliseconds.isFinite && $0.milliseconds > 0
        }
        guard let latest = valid.max(by: { $0.date < $1.date }) else {
            return .empty(at: now)
        }

        let baselineEnd = calendar.startOfDay(for: latest.date)
        let baselineStart = calendar.date(byAdding: .day, value: -14, to: baselineEnd)!
        let historical = valid.filter { $0.date >= baselineStart && $0.date < baselineEnd }
        let groups = Dictionary(grouping: historical) { calendar.startOfDay(for: $0.date) }
        let dailyMedians = groups.values.map { median($0.map(\.milliseconds)) }
        let enoughData = dailyMedians.count >= 5 && historical.count >= 10
        let baseline = enoughData ? median(dailyMedians) : nil
        let fresh = now.timeIntervalSince(latest.date) < StressSnapshot.maximumAge
        let score: Int?
        if fresh, let baseline {
            // Equal to baseline -> 50; half of baseline -> 95.
            let estimate = 50 - 45 * log2(latest.milliseconds / baseline)
            score = Int(min(100, max(0, estimate)).rounded())
        } else {
            score = nil
        }

        return StressSnapshot(
            generatedAt: now, sampleAt: latest.date,
            hrvMilliseconds: latest.milliseconds,
            baselineMilliseconds: baseline, baselineDays: dailyMedians.count,
            score: score, heartRate: heartRate, heartRateAt: heartRateAt
        )
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? sorted[middle - 1] / 2 + sorted[middle] / 2
            : sorted[middle]
    }
}

