import SwiftUI
import WidgetKit
import StressCore

struct StressEntry: TimelineEntry {
    let date: Date
    let snapshot: StressSnapshot
}

struct StressTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StressEntry {
        StressEntry(date: Date(), snapshot: .empty())
    }

    func getSnapshot(in context: Context, completion: @escaping (StressEntry) -> Void) {
        completion(StressEntry(date: Date(), snapshot: SnapshotCache.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StressEntry>) -> Void) {
        let now = Date()
        let snapshot = SnapshotCache.read()
        var entries = [StressEntry(date: now, snapshot: snapshot)]
        // Publish an explicit expiry entry; a stale score must not stay on the face.
        if let expiry = snapshot.expiresAt, expiry > now {
            entries.append(StressEntry(date: expiry, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(1_800))))
    }
}

struct StressComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StressEntry

    private var score: Int? { entry.snapshot.displayScore(at: entry.date) }
    private var color: Color {
        guard let score else { return .secondary }
        return score < 65 ? .green : score < 80 ? .orange : .red
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                if let score {
                    Gauge(value: Double(score), in: 0...100) {
                        Image(systemName: "heart.text.square")
                    } currentValueLabel: {
                        Text("\(score)")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "heart.text.square")
                        Text("—")
                    }
                }
            case .accessoryInline:
                Text("压力 \(score.map(String.init) ?? "—") · \(entry.snapshot.label(at: entry.date))")
            default:
                HStack(spacing: 8) {
                    Text(score.map(String.init) ?? "—")
                        .font(.title2.bold()).foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.snapshot.label(at: entry.date)).font(.headline)
                        if let date = entry.snapshot.sampleAt {
                            Text(date, style: .time).font(.caption2)
                        } else {
                            Text("打开手表 App 授权").font(.caption2)
                        }
                    }
                }
            }
        }
        .privacySensitive()
        .containerBackground(for: .widget) { Color.black }
    }
}

@main
struct WatchStressComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchStressComplication", provider: StressTimelineProvider()) {
            StressComplicationView(entry: $0)
        }
        .configurationDisplayName("压力观察")
        .description("显示最近一次 HRV 的压力估计和数据时间。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

