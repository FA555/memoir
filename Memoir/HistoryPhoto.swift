import CoreGraphics
import Foundation

struct HistoryPhoto: Identifiable, Hashable {
  let id: String
  let creationDate: Date
  let pixelWidth: Int
  let pixelHeight: Int

  var aspectRatio: CGFloat {
    guard pixelHeight > 0 else { return 1 }
    return max(0.25, CGFloat(pixelWidth) / CGFloat(pixelHeight))
  }
}
