import AppKit
import SwiftUI

/// Browser task status pill (docs/design-guide.md §4): a 24 pt capsule beside Hush's head while a task runs with
/// its card closed. A coloured dot (blue working, orange needs you, green done) and "In Comet · 3 of 5".
/// Clicking it reopens the card.
@MainActor
final class TaskStatusPill {
    final class Model: ObservableObject {
        @Published var text = ""
        @Published var color: Color = HushColor.working
    }

    let model = Model()
    var onClick: (() -> Void)?
    private var panel: NSPanel?

    var isShown: Bool { panel?.isVisible ?? false }

    func show(text: String, color: Color, beside character: NSRect) {
        model.text = text
        model.color = color
        let p = panel ?? make()
        panel = p
        place(beside: character)
        p.orderFrontRegardless()
    }

    func update(text: String, color: Color) {
        model.text = text
        model.color = color
        if let p = panel, let h = p.contentView { p.setContentSize(h.fittingSize) }
    }

    func relayout(beside character: NSRect) { if isShown { place(beside: character) } }

    func hide() { panel?.orderOut(nil) }

    private func place(beside c: NSRect) {
        guard let p = panel, let h = p.contentView else { return }
        let size = h.fittingSize
        let vf = NSScreen.main?.visibleFrame ?? .zero
        // To the right of the head, or the left when there's no room.
        var x = c.maxX + 6
        if x + size.width > vf.maxX - 12 { x = c.minX - 6 - size.width }
        let y = min(vf.maxY - size.height - 12, c.maxY - size.height - 8)
        p.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func make() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        let view = PillView(model: model) { [weak self] in self?.onClick?() }
        p.contentView = NSHostingView(rootView: view)
        return p
    }

    private struct PillView: View {
        @ObservedObject var model: Model
        let click: () -> Void
        var body: some View {
            Button(action: click) {
                HStack(spacing: 6) {
                    Circle().fill(model.color).frame(width: 7, height: 7)
                    Text(model.text).font(HushFont.footer.weight(.medium)).lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(HushColor.hairline, lineWidth: 0.5))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Show the browser task")
        }
    }
}
