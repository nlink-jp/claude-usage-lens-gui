import SwiftUI

/// Weekly-budget settings (⌘, / "Settings…" in the popover). Binds the
/// UserDefaults keys via @AppStorage; UsageModel reads the same keys.
struct SettingsView: View {
    @EnvironmentObject var model: UsageModel

    @AppStorage(SettingsKey.weeklyEnabled) private var enabled = false
    @AppStorage(SettingsKey.limitBasis) private var basisRaw = LimitBasis.cost.rawValue
    @AppStorage(SettingsKey.limitCost) private var limitCost = 200.0
    @AppStorage(SettingsKey.limitTokens) private var limitTokens = 50_000_000.0
    @AppStorage(SettingsKey.resetWeekday) private var resetWeekday = 2
    @AppStorage(SettingsKey.resetHour) private var resetHour = 0
    @AppStorage(SettingsKey.resetMinute) private var resetMinute = 0
    @AppStorage(SettingsKey.warnPercent) private var warnPercent = 80.0
    @AppStorage(SettingsKey.criticalPercent) private var criticalPercent = 95.0

    private var basis: LimitBasis { LimitBasis(rawValue: basisRaw) ?? .cost }

    var body: some View {
        Form {
            Section {
                Toggle("Monitor weekly budget", isOn: $enabled)
                    .onChange(of: enabled) { _, on in
                        if on { model.requestNotificationAuth() }
                        model.refreshToday()
                    }
                Text("A configurable budget — Claude's actual weekly limit can't be read, so set your own. Warns as you approach it.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Budget") {
                Picker("Measure by", selection: $basisRaw) {
                    ForEach(LimitBasis.allCases) { Text($0.label).tag($0.rawValue) }
                }
                if basis == .cost {
                    TextField("Weekly limit ($)", value: $limitCost, format: .number)
                } else {
                    TextField("Weekly limit (tokens, in+out)", value: $limitTokens, format: .number)
                }
            }
            .disabled(!enabled)

            Section("Reset") {
                Picker("Reset day", selection: $resetWeekday) {
                    ForEach(1...7, id: \.self) { Text(Self.weekdayName($0)).tag($0) }
                }
                DatePicker("Reset time", selection: resetTime, displayedComponents: .hourAndMinute)
                Text("Weekly window starts at this local day/time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!enabled)

            Section("Warning thresholds") {
                Stepper("Warning at \(Int(warnPercent))%", value: $warnPercent, in: 1...100, step: 5)
                Stepper("Critical at \(Int(criticalPercent))%", value: $criticalPercent, in: 1...100, step: 5)
            }
            .disabled(!enabled)

            if enabled, let w = model.weeklyStatus {
                Section("Current") {
                    LabeledContent("This week",
                        value: "\(UsageModel.amount(w.used, w.basis)) / \(UsageModel.amount(w.limit, w.basis))  (\(Int(w.percent))%)")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { model.refreshToday() }
    }

    /// A Date binding over just the hour/minute settings for the time picker.
    private var resetTime: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = resetHour
                c.minute = resetMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                resetHour = c.hour ?? 0
                resetMinute = c.minute ?? 0
            }
        )
    }

    static func weekdayName(_ weekday: Int) -> String {
        // Calendar weekday: 1 = Sunday … 7 = Saturday.
        let symbols = Calendar.current.weekdaySymbols // ["Sunday", ...]
        let idx = (weekday - 1) % 7
        return symbols.indices.contains(idx) ? symbols[idx] : "\(weekday)"
    }
}
