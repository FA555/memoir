import SwiftUI

struct PageDotsView: View {
  let count: Int
  let selectedIndex: Int

  private var maxVisibleDots: Int { 15 }

  private var visibleRange: ClosedRange<Int> {
    guard count > maxVisibleDots else { return 0...(max(0, count - 1)) }

    let half = maxVisibleDots / 2
    let lower = max(0, min(selectedIndex - half, count - maxVisibleDots))
    let upper = min(count - 1, lower + maxVisibleDots - 1)
    return lower...upper
  }

  var body: some View {
    HStack(spacing: 7) {
      if visibleRange.lowerBound > 0 {
        DotOverflowMark()
      }

      ForEach(Array(visibleRange), id: \.self) { index in
        Circle()
          .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.45))
          .frame(width: index == selectedIndex ? 8 : 6, height: index == selectedIndex ? 8 : 6)
      }

      if visibleRange.upperBound < count - 1 {
        DotOverflowMark()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.58), in: Capsule())
  }
}

struct DotOverflowMark: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(Color.white.opacity(0.45))
      .frame(width: 10, height: 3)
  }
}
