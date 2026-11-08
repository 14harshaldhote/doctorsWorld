import GameCore
import SwiftUI

/// Shared colours for the SwiftUI screens.
enum Theme {
    static let teal = Color(red: 0.05, green: 0.55, blue: 0.60)
    static let deepTeal = Color(red: 0.15, green: 0.31, blue: 0.43)
    static let stable = Color(red: 0.19, green: 0.64, blue: 0.42)
    static let serious = Color(red: 0.95, green: 0.62, blue: 0.10)
    static let critical = Color(red: 0.89, green: 0.26, blue: 0.29)

    static func status(_ status: PatientStatus) -> Color {
        switch status {
        case .stable: stable
        case .serious: serious
        case .critical, .crashed: critical
        }
    }

    /// A shape for each status, so status never depends on colour alone.
    static func statusSymbol(_ status: PatientStatus) -> String {
        switch status {
        case .stable: "checkmark.circle.fill"
        case .serious: "exclamationmark.triangle.fill"
        case .critical, .crashed: "exclamationmark.octagon.fill"
        }
    }
}

/// Soft clinical gradient used behind menus.
struct WardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.47, blue: 0.55), Theme.deepTeal],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// A small rounded tag, used for symptoms and findings.
struct Chip: View {
    let text: String
    var tint: Color = .secondary
    var filled = false

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(filled ? Color.white : tint)
            .background(filled ? tint : tint.opacity(0.12), in: Capsule())
    }
}

/// Lays children out left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.maxY } ?? 0
        let width = rows.map { $0.width }.max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var maxY: CGFloat { y + height }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.items.isEmpty && row.width + spacing + size.width > width {
                let next = Row(y: row.maxY + spacing)
                rows.append(next)
                row = next
            }
            let x = row.items.isEmpty ? 0 : row.width + spacing
            row.items.append(Item(index: index, x: x, size: size))
            row.width = x + size.width
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
