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
            // via @AppStorage, so a change to either re-evaluates this label live.
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("Usage Analysis", id: "analysis") {
            AnalysisView()
                .environmentObject(model)
                .frame(minWidth: 620, minHeight: 460)
        }
        .windowResizability(.contentMinSize)
    }

    /// Menu-bar content per the chosen display mode. "both" renders two rows via
    /// an NSImage (a template image so it adapts to the light/dark menu bar).
    @ViewBuilder
    private var menuBarLabel: some View {
        switch menuBarMode {
        case .price:
            Text(model.todayPrice)
        case .tokens:
            Text(model.todayTokens)
        case .both:
            Image(nsImage: Self.twoLineImage(top: model.todayPrice, bottom: model.todayTokens))
        }
    }

    /// Build the model and kick off its refresh loop at launch.
    private static func makeModel() -> UsageModel {
        let m = UsageModel()
        m.start()
        return m
    }

    /// Render two stacked, right-aligned lines to a template NSImage sized to fit
    /// the menu bar. Both lines use the same point size so the tokens line stays
    /// legible; the price is emphasised by weight, not size. Template ⇒ the system
    /// tints it for light/dark automatically.
    static func twoLineImage(top: String, bottom: String) -> NSImage {
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
            .font: topFont, .paragraphStyle: topPara, .foregroundColor: NSColor.black,
        ]))
        s.append(NSAttributedString(string: bottom, attributes: [
            .font: botFont, .paragraphStyle: botPara, .foregroundColor: NSColor.black,
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
        img.isTemplate = true
        return img
    }
}
