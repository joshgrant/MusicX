// © BCE Labs, 2024. All rights reserved.
//

import SwiftUI

/// A single line of text that stays put (centered) when it fits, and
/// scrolls continuously in one direction — billboard-style — when it
/// doesn't.
struct MarqueeText: View {

    let text: String
    var font: Font = .body

    /// Scroll speed, in points per second.
    private let speed: Double = 30
    /// Blank run between the end of the text and its next repetition.
    private let gap: CGFloat = 48

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        // The hidden copy gives the view its intrinsic height and reports
        // the two widths that decide whether scrolling is needed.
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) {
                textWidth = $0
            }
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) {
                containerWidth = $0
            }
            .overlay {
                if textWidth > containerWidth {
                    scrollingText
                } else {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                }
            }
            .clipped()
    }

    private var scrollingText: some View {
        TimelineView(.animation) { context in
            let cycle = Double(textWidth + gap)
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let offset = CGFloat((elapsed * speed).truncatingRemainder(dividingBy: cycle))

            // Two copies chase each other so the loop never shows a seam.
            HStack(spacing: gap) {
                Text(text).font(font).lineLimit(1).fixedSize()
                Text(text).font(font).lineLimit(1).fixedSize()
            }
            .offset(x: -offset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MarqueeText(text: "Tame Impala – Currents", font: .title2)
        MarqueeText(
            text: "A Very Long Artist Name – An Even Longer Album Title That Cannot Possibly Fit",
            font: .title2)
    }
    .padding()
}
