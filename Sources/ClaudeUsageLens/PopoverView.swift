import AppKit
import SwiftUI

/// The dropdown shown when the menu-bar item is clicked: today's cost + tokens,
/// a 30-day projection, and buttons to open the analysis window / refresh / quit.
struct PopoverView: View {
    @EnvironmentObject var model: UsageModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("menuBarMode") private var menuBarMode: MenuBarMode = .price

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today").font(.headline)

            if let s = model.todaySummary {
                Text(String(format: "$%.2f", s.totalUSD))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
                    tokenRow("Input", s.inputTokens)
                    tokenRow("Output", s.outputTokens)
                    tokenRow("Cache", s.cacheTokens)
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Divider()
                HStack {
                    Text("Last 30 days").foregroundStyle(.secondary)
                    Spacer()
                    Text(model.last30USD.map { String(format: "$%.2f", $0) } ?? "—").monospacedDigit()
                }
                .font(.callout)
            } else if let err = model.lastError {
                Label("Couldn't load usage", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(err)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = model.lastErrorDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }.frame(height: 60)
            }

            if let w = model.weeklyStatus {
                Divider()
                weeklySection(w)
            }

            if let ts = model.lastUpdated {
                Text("Updated \(ts.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu bar").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $menuBarMode) {
                    ForEach(MenuBarMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Button("Analysis…") {
                    model.loadAnalysis()
                    openWindow(id: "analysis")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Refresh") { model.refreshToday() }
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
        // Always show fresh numbers when the popover is opened, even if the timer
        // was throttled while the app sat idle in the menu bar.
        .onAppear { model.refreshToday() }
    }

    /// Weekly-budget progress: used / limit, a colored bar, %, and the next reset.
    @ViewBuilder
    private func weeklySection(_ w: WeeklyStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("This week").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text("\(UsageModel.amount(w.used, w.basis)) / \(UsageModel.amount(w.limit, w.basis))")
                    .font(.callout).monospacedDigit()
                    .foregroundStyle(w.state.color ?? .primary)
            }
            ProgressView(value: min(w.percent, 100), total: 100)
                .tint(w.state.color ?? .accentColor)
            HStack {
                Text("\(Int(w.percent))% used").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("resets \(UsageModel.resetLabel(w.nextReset))").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func tokenRow(_ label: String, _ n: Int) -> some View {
        GridRow {
            Text(label)
            Spacer()
            Text(Self.compact(n)).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }

    /// 1_234_567 → "1.2M", 12_345 → "12.3K".
    static func compact(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 1_000_000...: return String(format: "%.1fM", v / 1_000_000)
        case 1_000...: return String(format: "%.1fK", v / 1_000)
        default: return "\(n)"
        }
    }
}
