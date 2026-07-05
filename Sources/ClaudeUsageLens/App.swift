import SwiftUI

@main
struct ClaudeUsageLensApp: App {
    @StateObject private var model = Self.makeModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            // The App holds `model` as a @StateObject, so a change to its
            // @Published today's-summary re-evaluates this label live.
            Text(model.menuBarLabel)
        }
        .menuBarExtraStyle(.window)

        Window("Usage Analysis", id: "analysis") {
            AnalysisView()
                .environmentObject(model)
                .frame(minWidth: 680, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }

    /// Build the model and kick off its refresh loop at launch.
    private static func makeModel() -> UsageModel {
        let m = UsageModel()
        m.start()
        return m
    }
}
