import Foundation
import StressCore

enum SnapshotCache {
    private static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "StressAppGroup") as? String,
              !group.isEmpty,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        return folder.appendingPathComponent("stress-snapshot.json")
    }

    static func read() -> StressSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(StressSnapshot.self, from: data)
        else { return .empty() }
        return snapshot
    }

    static func write(_ snapshot: StressSnapshot) throws {
        guard let url = fileURL else { throw CacheError.containerUnavailable }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    enum CacheError: LocalizedError {
        case containerUnavailable

        var errorDescription: String? {
            "表盘缓存不可用：请检查签名后的 App Group 与 StressAppGroup 是否一致。"
        }
    }
}

