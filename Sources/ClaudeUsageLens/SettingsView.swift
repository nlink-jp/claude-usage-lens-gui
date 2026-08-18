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
    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled = true

    @State private var calibUtilization: Double = 0
    @State private var calibResetsAt = Date()

    private var basis: LimitBasis { LimitBasis(rawValue: basisRaw) ?? .cost }

    var body: some View {
        Form {
            Section {
                Toggle("Monitor weekly budget", isOn: $enabled)
                    .onChange(of: enabled) { _, on in
                        if on && notificationsEnabled { model.requestNotificationAuth() }
                        model.refreshWeekly()
                    }
                Text("Warns as you approach the weekly limit. Calibrate below to anchor it to the official /usage reading; otherwise your assumed budget is used.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Show notifications", isOn: $notificationsEnabled)
                    .disabled(!enabled)
                    .onChange(of: notificationsEnabled) { _, on in
                        if on && enabled { model.requestNotificationAuth() }
                    }
                Text("Off = colour/bar only, no system notifications.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Calibration") {
                TextField("Official /usage shows (%)", value: $calibUtilization, format: .number)
                DatePicker("Resets at", selection: $calibResetsAt)
                Button("Calibrate") {
                    model.calibrationMessage = nil
                    model.calibrate(utilizationPct: calibUtilization, resetsAt: calibResetsAt)
                }
                .disabled(calibUtilization <= 0 || calibUtilization > 100)
                Text("Run /usage in Claude Code, then enter the weekly percentage and its reset time. The real cap is derived from it — no private API involved.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let msg = model.calibrationMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.hasPrefix("Calibrated") ? Color.green : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let w = model.weeklyStatus, w.calibrated {
                    LabeledContent("Active cap",
                        value: "\(UsageModel.amount(w.limit, w.basis)) (calibrated \(Self.ageLabel(w.calibrationAgeDays)))")
                }
            }
            .disabled(!enabled)

            Section("Assumed budget (fallback)") {
                Picker("Measure by", selection: $basisRaw) {
                    ForEach(LimitBasis.allCases) { Text($0.label).tag($0.rawValue) }
                }
                if basis == .cost {
                    TextField("Weekly limit ($)", value: $limitCost, format: .number)
                } else {
                    TextField("Weekly limit (tokens, in+out)", value: $limitTokens, format: .number)
                }
                Text("Used only while no calibration is recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!enabled)

            Section("Reset") {
                Picker("Reset day", selection: $resetWeekday) {
                    ForEach(1...7, id: \.self) { Text(Self.weekdayName($0)).tag($0) }
                }
                DatePicker("Reset time", selection: resetTime, displayedComponents: .hourAndMinute)
                Text("Weekly window starts at this local day/time. When calibrated, the official reset cadence takes over.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                        value: "\(UsageModel.amount(w.used, w.basis)) / \(UsageModel.amount(w.limit, w.basis))  (\(w.usedPercentDisplay)%)")
                    LabeledContent("Remaining",
                        value: "\(UsageModel.amount(w.remaining, w.basis))  (\(w.remainingPercentDisplay)%)")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        // Instant feedback: limit/basis/thresholds rebuild the status from cached
        // usage (no CLI); reset day/time re-query the new window.
        .onChange(of: basisRaw) { _, _ in model.applyWeeklySettings() }
        .onChange(of: limitCost) { _, _ in model.applyWeeklySettings() }
        .onChange(of: limitTokens) { _, _ in model.applyWeeklySettings() }
        .onChange(of: warnPercent) { _, _ in model.applyWeeklySettings() }
        .onChange(of: criticalPercent) { _, _ in model.applyWeeklySettings() }
        .onChange(of: resetWeekday) { _, _ in model.refreshWeekly() }
        .onChange(of: resetHour) { _, _ in model.refreshWeekly() }
        .onChange(of: resetMinute) { _, _ in model.refreshWeekly() }
        // Prefill the calibration reset picker with the best-known next reset.
        .onAppear { calibResetsAt = model.weeklyStatus?.nextReset ?? Date() }
    }

    /// "0.3 days ago" → a compact staleness label for the active cap.
    static func ageLabel(_ days: Double?) -> String {
        guard let days else { return "just now" }
        if days < 1 { return "today" }
        return String(format: "%.0fd ago", days)
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
