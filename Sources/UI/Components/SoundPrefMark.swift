import SwiftUI
import AppKit

// The Sound Pref mark lives on a 16x16 grid with a 1.5-unit stroke, round
// caps and round joins. Everything here derives from those numbers, so the
// mark is byte-identical in shape at 18pt in the menu bar and at 1024pt.
//
//   node        filled input, r 1.65 at (2.35, 8)
//   trunk       (4, 8) -> (7, 8)
//   branches    (7, 8) -> (10.4, 4.6) and (7, 8) -> (10.4, 11.4)   [45 deg]
//   outputs     x 12.9, y 1.8-7.4 (primary) and y 10-12.8 (secondary)
//
// The two output terminals are intentionally unequal: that asymmetry is the
// product idea. Keep the ratio (5.6 : 2.8) if you ever redraw it.

enum SoundPrefMarkGeometry {
    static let grid: CGFloat = 16
    static let strokeWidth: CGFloat = 1.5

    /// Filled input node, as a bounding box on the 16x16 grid.
    static let node = CGRect(x: 0.70, y: 6.35, width: 3.30, height: 3.30)

    /// Trunk, both branches and both output terminals, on the 16x16 grid.
    static var strokes: Path {
        var p = Path()
        p.move(to: CGPoint(x: 4.0, y: 8.0))
        p.addLine(to: CGPoint(x: 7.0, y: 8.0))
        p.addLine(to: CGPoint(x: 10.4, y: 4.6))
        p.move(to: CGPoint(x: 7.0, y: 8.0))
        p.addLine(to: CGPoint(x: 10.4, y: 11.4))
        p.move(to: CGPoint(x: 12.9, y: 1.8))
        p.addLine(to: CGPoint(x: 12.9, y: 7.4))
        p.move(to: CGPoint(x: 12.9, y: 10.0))
        p.addLine(to: CGPoint(x: 12.9, y: 12.8))
        return p
    }
}

// MARK: - SwiftUI

/// Resolution-independent mark. Takes its colour from the foreground style,
/// so `.foregroundStyle(.primary)` or a tint just works.
struct SoundPrefMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / SoundPrefMarkGeometry.grid
            let t = CGAffineTransform(scaleX: s, y: s)
            ZStack {
                Path { $0.addEllipse(in: SoundPrefMarkGeometry.node) }
                    .applying(t)
                    .fill()
                SoundPrefMarkGeometry.strokes
                    .applying(t)
                    .stroke(style: StrokeStyle(
                        lineWidth: SoundPrefMarkGeometry.strokeWidth * s,
                        lineCap: .round,
                        lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - AppKit (NSStatusItem)

extension NSImage {
    /// Template image for a status item button. macOS handles light mode,
    /// dark mode and the pressed state for you once isTemplate is true.
    static func soundPrefMark(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize),
                            flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = rect.width / SoundPrefMarkGeometry.grid
            ctx.translateBy(x: 0, y: rect.height)   // design grid is y-down
            ctx.scaleBy(x: s, y: -s)
            ctx.setFillColor(.black)
            ctx.setStrokeColor(.black)
            ctx.fillEllipse(in: SoundPrefMarkGeometry.node)
            ctx.setLineWidth(SoundPrefMarkGeometry.strokeWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(SoundPrefMarkGeometry.strokes.cgPath)
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - Use it
//
// SwiftUI, no asset needed:
//
//     MenuBarExtra {
//         RoutingPanel()
//     } label: {
//         SoundPrefMark().frame(width: 18, height: 18)
//     }
//     .menuBarExtraStyle(.window)
//
// Or from the asset catalogue, which gets you free template tinting:
//
//     } label: {
//         Image("MenuBarIcon")
//     }
//
// AppKit status item:
//
//     statusItem = NSStatusBar.system.statusItem(withLength: .variableLength)
//     statusItem.button?.image = .soundPrefMark()
//
// Suggested active state: when any app is routed away from the system
// default, tint the mark with the accent blue (#67A6FB) rather than adding
// a badge - the silhouette should never change in the menu bar.
