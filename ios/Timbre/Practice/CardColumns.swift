import SwiftUI

/// The card grid a tab lays out at regular width (Play, Learn, Progress on iPad): how many columns its content
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
