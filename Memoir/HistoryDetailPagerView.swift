import SwiftUI

struct HistoryDetailPagerView: View {
  let photos: [HistoryPhoto]
  @Binding var selectedIndex: Int

  @State private var presentedImageHeight: CGFloat = 320

  private var clampedIndex: Int {
    min(max(selectedIndex, 0), max(photos.count - 1, 0))
  }

  private var currentPhoto: HistoryPhoto {
    photos[clampedIndex]
  }

  private var safeSelection: Binding<Int> {
    Binding(
      get: { clampedIndex },
      set: { newValue in
        selectedIndex = min(max(newValue, 0), max(photos.count - 1, 0))
      }
    )
  }

  var body: some View {
    GeometryReader { proxy in
      let contentWidth = max(120, proxy.size.width)
      let targetImageHeight = dynamicImageHeight(
        containerWidth: contentWidth - 32, aspectRatio: currentPhoto.aspectRatio)

      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 14) {
          Text(currentPhoto.creationDate, format: .dateTime.year())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)

          Text("detail.memory_of_day")
            .font(.title2.bold())

          Text(
            currentPhoto.creationDate.formatted(
              .dateTime.year().month(.wide).day().weekday(.wide).hour().minute())
          )
          .font(.body)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .frame(width: contentWidth, alignment: .leading)

        Text("\(clampedIndex + 1) / \(photos.count)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: contentWidth - 32, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 8)

        PageDotsView(count: photos.count, selectedIndex: clampedIndex)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 8)

        TabView(selection: safeSelection) {
          ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
            HistoryDetailPageView(photo: photo)
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: contentWidth)
        .frame(height: presentedImageHeight + 24)
      }
      .frame(width: contentWidth)
      .frame(maxWidth: .infinity, alignment: .top)
      .onAppear {
        selectedIndex = min(max(selectedIndex, 0), max(photos.count - 1, 0))
        presentedImageHeight = targetImageHeight
      }
      .onChange(of: clampedIndex) { _, _ in
        updatePresentedHeight(to: targetImageHeight)
      }
      .onChange(of: photos.count) { _, _ in
        selectedIndex = min(max(selectedIndex, 0), max(photos.count - 1, 0))
        presentedImageHeight = dynamicImageHeight(
          containerWidth: contentWidth - 32, aspectRatio: currentPhoto.aspectRatio)
      }
    }
  }

  private func dynamicImageHeight(containerWidth: CGFloat, aspectRatio: CGFloat) -> CGFloat {
    let safeWidth = max(120, containerWidth)
    let rawHeight = safeWidth / max(0.25, aspectRatio)
    let minHeight = safeWidth * 0.68
    let maxHeight = safeWidth * 1.18
    return min(max(rawHeight, minHeight), maxHeight)
  }

  private func updatePresentedHeight(to target: CGFloat) {
    let blended = presentedImageHeight * 0.72 + target * 0.28
    withAnimation(.easeOut(duration: 0.18)) {
      presentedImageHeight = blended
    }
  }
}
