import XCTest
@testable import StressCore

final class StressEstimatorTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func history(days: Int = 5, value: Double = 40) -> [HRVReading] {
        let today = calendar.startOfDay(for: now)
        return (1...days).flatMap { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return [
                HRVReading(date: day.addingTimeInterval(600), milliseconds: value),
                HRVReading(date: day.addingTimeInterval(1_200), milliseconds: value)
            ]
        }
    }

    func testDoesNotScoreWithoutPersonalBaseline() {
        let result = StressEstimator.makeSnapshot(
            readings: [HRVReading(date: now, milliseconds: 20)], now: now, calendar: calendar
        )
        XCTAssertNil(result.score)
        XCTAssertEqual(result.label(at: now), "基线积累中")
    }

    func testSampleDayCannotInflateItsOwnBaseline() {
        var readings = history()
        readings.append(HRVReading(date: now, milliseconds: 20))
        readings.append(HRVReading(date: now.addingTimeInterval(-60), milliseconds: 200))
        let result = StressEstimator.makeSnapshot(readings: readings, now: now, calendar: calendar)
        XCTAssertEqual(result.baselineMilliseconds, 40)
        XCTAssertEqual(result.score, 95)
    }

    func testSamplingDensityDoesNotWeightOneDayMoreHeavily() {
        var readings = history()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        readings += (1...100).map {
            HRVReading(date: yesterday.addingTimeInterval(Double($0)), milliseconds: 200)
        }
        readings.append(HRVReading(date: now, milliseconds: 40))
        let result = StressEstimator.makeSnapshot(readings: readings, now: now, calendar: calendar)
        XCTAssertEqual(result.baselineMilliseconds, 40)
        XCTAssertEqual(result.score, 50)
    }

    func testStaleCacheHidesScoreExactlyAtExpiry() {
        let result = StressEstimator.makeSnapshot(
            readings: history() + [HRVReading(date: now, milliseconds: 40)],
            now: now, calendar: calendar
        )
        XCTAssertEqual(result.displayScore(at: now.addingTimeInterval(7_199)), 50)
        XCTAssertNil(result.displayScore(at: now.addingTimeInterval(7_200)))
        XCTAssertEqual(result.label(at: now.addingTimeInterval(7_200)), "数据较旧")
    }

    func testRejectsInvalidAndFutureMeasurements() {
        let readings = [
            HRVReading(date: now, milliseconds: .nan),
            HRVReading(date: now, milliseconds: 0),
            HRVReading(date: now, milliseconds: -1),
            HRVReading(date: now.addingTimeInterval(60), milliseconds: 40)
        ]
        let result = StressEstimator.makeSnapshot(readings: readings, now: now, calendar: calendar)
        XCTAssertNil(result.hrvMilliseconds)
        XCTAssertNil(result.score)
    }
}

