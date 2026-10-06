import SwiftUI
import StressCore

struct SummaryView: View {
    @ObservedObject var health: HealthStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(spacing: 14) {
                    Text("压力估计").font(.headline)
                    Text(health.snapshot.displayScore(at: context.date).map(String.init) ?? "—")
                        .font(.system(size: 58, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(scoreColor(at: context.date))
                    Text(health.snapshot.label(at: context.date)).font(.headline)

                    if let hrv = health.snapshot.hrvMilliseconds {
                        Text("HRV \(hrv, specifier: "%.0f") ms")
                    }
                    if let date = health.snapshot.sampleAt {
                        VStack(spacing: 3) {
                            Text("HRV 样本时间").font(.caption2)
                            Text(date, style: .date).font(.caption)
                            Text(date, style: .time).font(.caption)
                        }.foregroundStyle(.secondary)
                    }
                    if let baseline = health.snapshot.baselineMilliseconds {
                        Text("个人基线 \(baseline, specifier: "%.0f") ms")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("需要至少 5 个历史日期、10 个 HRV 样本建立个人基线。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let rate = health.snapshot.heartRate, let date = health.snapshot.heartRateAt {
                        VStack(spacing: 3) {
                            Text("最近心率 \(rate, specifier: "%.0f") 次／分")
                            Text(date, style: .time).font(.caption2)
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    if let message = health.message {
                        Text(message).font(.caption).foregroundStyle(.orange)
                    }
                    if health.busy { ProgressView() }
                    Button("授权健康数据") { Task { await health.requestAccess() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(health.busy)
                    Button("刷新") { Task { await health.refresh() } }
                        .disabled(health.busy)
                    Text("当前验证版在打开 App 或点击刷新时更新。超过 2 小时的 HRV 不显示压力分数。")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("根据 HRV 相对个人基线估计，仅用于观察变化。运动、睡眠、呼吸等都会影响结果。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding()
            }
        }
    }

    private func scoreColor(at date: Date) -> Color {
        guard let score = health.snapshot.displayScore(at: date) else { return .secondary }
        if score < 65 { return .green }
        if score < 80 { return .orange }
        return .red
    }
}

