import SwiftUI

/// The card grid a tab lays out at regular width (Play, Learn, Songs, Progress on iPad): how many columns its content
/// width holds and how wide they are. One column means the phone's single-column layout; two from about an iPad in
/// portrait, three from about an iPad in landscape. Chosen from the width the tab actually has (Split View and Stage
/// Manager windows included), never from the device.
struct CardColumns: Equatable {
    /// 1, 2 or 3.
    let count: Int
    /// One column's width.
    let unit: CGFloat
    /// Between columns, and between the cards of a row.
    static let spacing: CGFloat = 16

    /// - Parameter width: the content's width, inside the screen gutters.
    init(width: CGFloat) {
        count = width >= 1080 ? 3 : (width >= 700 ? 2 : 1)
        unit = max(0, (width - CGFloat(count - 1) * Self.spacing) / CGFloat(count))
    }

    /// The width of `columns` adjacent columns, with the spacing between them.
    func span(_ columns: Int) -> CGFloat {
        let n = CGFloat(max(1, min(columns, count)))
        return unit * n + Self.spacing * (n - 1)
    }
}

/// Columns of cards side by side, top-aligned, each `width` wide. Every column but the last stands at its own height;
/// the last is offered the height of the tallest of the others, so a list at its foot (Progress's recent sessions, in a
/// `ViewThatFits` of shorter and longer versions) shows as many rows as fit beside them instead of running on alone
/// below them. Should the last column need more than that even at its shortest, the row grows to fit it.
struct BalancedColumns: Layout {
    let width: CGFloat
    var spacing: CGFloat = CardColumns.spacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let count = CGFloat(subviews.count)
        return CGSize(width: max(0, width * count + spacing * (count - 1)), height: rowHeight(subviews))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let height = rowHeight(subviews)
        for (index, subview) in subviews.enumerated() {
            let last = index == subviews.count - 1
            let x = bounds.minX + CGFloat(index) * (width + spacing)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: last ? height : nil))
        }
    }

    /// The tallest of the other columns, or what the last one needs when offered that, if more.
    private func rowHeight(_ subviews: Subviews) -> CGFloat {
        guard let last = subviews.last else { return 0 }
        let others = subviews.dropLast().map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
        let fitted = last.sizeThatFits(ProposedViewSize(width: width, height: others)).height
        return max(others, fitted)
    }
}
