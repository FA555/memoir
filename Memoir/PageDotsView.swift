import SwiftUI

struct PageDotsView: View {
  let count: Int
  let selectedIndex: Int

  private var maxVisibleDots: Int { 11 }

  private var safeSelectedIndex: Int {
    min(max(selectedIndex, 0), max(0, count - 1))
  }

  private var visibleRange: ClosedRange<Int> {
    guard count > maxVisibleDots else { return 0...(max(0, count - 1)) }

    // Chunked window keeps selected dot visibly moving in long lists.
    let chunkStart = (safeSelectedIndex / maxVisibleDots) * maxVisibleDots
    let lower = max(0, min(chunkStart, count - maxVisibleDots))
    let upper = min(count - 1, lower + maxVisibleDots - 1)
    return lower...upper
  }

  var body: some View {
    HStack(spacing: 7) {
      if visibleRange.lowerBound > 0 {
        DotOverflowMark(direction: .left)
      }

      ForEach(Array(visibleRange), id: \.self) { index in
        Capsule()
          .fill(index == safeSelectedIndex ? Color.white : Color.white.opacity(0.45))
          .frame(width: index == safeSelectedIndex ? 14 : 6, height: 6)
          .animation(.easeOut(duration: 0.16), value: safeSelectedIndex)
      }

      if visibleRange.upperBound < count - 1 {
        DotOverflowMark(direction: .right)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.58), in: Capsule())
  }
}

struct DotOverflowMark: View {
  enum Direction {
    case left
    case right
  }

  let direction: Direction

  var body: some View {
    HStack(spacing: 2) {
      if direction == .left {
        Image(systemName: "chevron.left")
      }

      RoundedRectangle(cornerRadius: 2)
        .fill(Color.white.opacity(0.45))
        .frame(width: 8, height: 3)

      if direction == .right {
        Image(systemName: "chevron.right")
      }
    }
    .font(.system(size: 8, weight: .bold))
    .foregroundStyle(Color.white.opacity(0.7))
  }
}
