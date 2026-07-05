import Charts
import SwiftUI

/// The expanded analysis window: daily cost trend, per-model and top-project
/// breakdowns, over a selectable period. Data comes from the CLI's report --json.
struct AnalysisView: View {
    @EnvironmentObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            GroupBox("Daily cost (USD)") {
                if model.dailyRows.isEmpty {
                    emptyChart
                } else {
                    Chart(model.dailyRows) { row in
                        BarMark(
                            x: .value("Day", row.key),
                            y: .value("Cost", row.costUSD)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel(orientation: .vertical) } }
                    .frame(height: 200)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                GroupBox("By model") { barList(model.modelRows, label: { $0 }) }
                GroupBox("Top projects") { barList(model.projectRows, label: Self.lastPathComponent) }
            }

            if let err = model.lastError {
                Text(err).font(.caption).foregroundStyle(.orange).lineLimit(3)
            }
            Spacer()
        }
        .padding(18)
        .onAppear { model.loadAnalysis() }
    }

    private var header: some View {
        HStack {
            Text("Usage Analysis").font(.title2.bold())
            Spacer()
            Picker("", selection: $model.period) {
                Text("7 days").tag("7d")
                Text("30 days").tag("30d")
                Text("90 days").tag("90d")
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: model.period) { _, _ in model.loadAnalysis() }
            Button("Refresh") { model.loadAnalysis() }
        }
    }

    private func barList(_ rows: [Row], label: @escaping (String) -> String) -> some View {
        Group {
            if rows.isEmpty {
                emptyChart
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Cost", row.costUSD),
                        y: .value("Key", label(row.key))
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .annotation(position: .trailing) {
                        Text(String(format: "$%.0f", row.costUSD))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private var emptyChart: some View {
        HStack { Spacer(); Text("No data").foregroundStyle(.secondary); Spacer() }
            .frame(height: 200)
    }

    static func lastPathComponent(_ p: String) -> String {
        (p as NSString).lastPathComponent.isEmpty ? p : (p as NSString).lastPathComponent
    }
}
