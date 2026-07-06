import AppKit
import SwiftUI

@main
struct ClaudeUsageLensApp: App {
    @StateObject private var model = Self.makeModel()
    @AppStorage("menuBarMode") private var menuBarMode: MenuBarMode = .price

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            // The App holds `model` as a @StateObject and reads `menuBarMode`
            // via @AppStorage, so a change to either (incl. the weekly state)
            // re-evaluates this label live.
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("Usage Analysis", id: "analysis") {
            AnalysisView()
                .environmentObject(model)
                .frame(minWidth: 620, minHeight: 460)
        }
        .windowResizability(.contentMinSize)

        // A plain Window (not the Settings scene): a menu-bar (LSUIElement) app
        // can open + focus it reliably via openWindow + NSApp.activate, whereas the
        // Settings scene / SettingsLink often opens unfocused or not at all.
        Window("Weekly Budget", id: "settings") {
            SettingsView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }

    /// Menu-bar content per the chosen display mode, tinted by the weekly-budget
    /// state (orange = warning, red = critical) so a low balance is visible
    /// regardless of what the label shows.
    @ViewBuilder
    private var menuBarLabel: some View {
        let state = model.weeklyStatus?.state ?? .normal
        switch menuBarMode {
        case .price:
            colored(Text(model.todayPrice), state.color)
        case .tokens:
            colored(Text(model.todayTokens), state.color)
        case .weekly:
            colored(Text(model.weeklyRemainingLabel), state.color)
        case .both:
            Image(nsImage: Self.twoLineImage(
                top: model.todayPrice, bottom: model.todayTokens,
                color: Self.menuNSColor(state)))
        }
    }

    @ViewBuilder
    private func colored(_ text: Text, _ color: Color?) -> some View {
        if let color { text.foregroundStyle(color) } else { text }
    }

    private static func menuNSColor(_ state: LimitState) -> NSColor? {
        switch state {
        case .normal: return nil
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    /// Build the model and kick off its refresh loop at launch.
    private static func makeModel() -> UsageModel {
        let m = UsageModel()
        m.start()
        return m
    }

    /// Render two stacked, right-aligned lines to an NSImage sized to fit the menu
    /// bar. With no color it's a template image (auto-tints for light/dark); with a
    /// color (weekly warning/critical) it's rendered in that tint. Both lines use
    /// the same point size so the tokens line stays legible; the price is
    /// emphasised by weight, not size.
    static func twoLineImage(top: String, bottom: String, color: NSColor? = nil) -> NSImage {
        let fg = color ?? .black
        let topFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let botFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

        // Tight glyph lines (10px) plus a small gap between them, so the two rows
        // read as distinct without growing past the menu bar's height budget.
        let topPara = NSMutableParagraphStyle()
        topPara.alignment = .right
        topPara.minimumLineHeight = 10
        topPara.maximumLineHeight = 10
        topPara.paragraphSpacing = 3
        let botPara = NSMutableParagraphStyle()
        botPara.alignment = .right
        botPara.minimumLineHeight = 10
        botPara.maximumLineHeight = 10

        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: top + "\n", attributes: [
            .font: topFont, .paragraphStyle: topPara, .foregroundColor: fg,
        ]))
        s.append(NSAttributedString(string: bottom, attributes: [
            .font: botFont, .paragraphStyle: botPara, .foregroundColor: fg,
        ]))

        let bounds = s.size()
        let topMargin: CGFloat = 2
        let textH = ceil(bounds.height)
        let size = NSSize(width: ceil(bounds.width) + 2, height: textH + topMargin)
        let img = NSImage(size: size)
        img.lockFocus()
        // Draw into the lower `textH`, leaving `topMargin` empty above the top row.
        s.draw(in: NSRect(x: 0, y: 0, width: size.width, height: textH))
        img.unlockFocus()
        img.isTemplate = (color == nil)
        return img
    }
}
