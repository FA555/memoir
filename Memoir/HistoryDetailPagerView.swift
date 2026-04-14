import SwiftUI

struct HistoryDetailPagerView: View {
  let photos: [HistoryPhoto]
  @Binding var selectedIndex: Int
  let onDeleteCurrent: (String) async -> Void

  @State private var measuredWidth: CGFloat = 360

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
        selectedIndex = clamped(newValue)
      }
    )
  }

  private func clamped(_ index: Int) -> Int {
    min(max(index, 0), max(photos.count - 1, 0))
  }

  private var contentWidth: CGFloat {
    max(120, measuredWidth)
  }

  // Fixed canvas height avoids any layout jump when swiping between mixed aspect ratios.
  // Raised value helps portrait screenshots occupy most of the screen.
  private var fixedCanvasHeight: CGFloat {
    min(max((contentWidth - 32) * 1.75, 480), 820)
  }

  private var pagerBlockHeight: CGFloat {
    fixedCanvasHeight + 24
  }

  private var totalHeight: CGFloat {
    pagerBlockHeight + 126
  }

  var body: some View {
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
      .frame(width: contentWidth, height: pagerBlockHeight)

      HStack {
        Spacer()

        Button(role: .destructive) {
          Task {
            await onDeleteCurrent(currentPhoto.id)
          }
        } label: {
          Image(systemName: "trash")
            .font(.title2)
            .foregroundStyle(.red)
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("accessibility.delete_photo")
        .padding(.trailing, 16)
      }
      .padding(.top, 6)
    }
    .frame(width: contentWidth, height: totalHeight, alignment: .top)
    .frame(maxWidth: .infinity, alignment: .top)
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear {
            updateMeasuredWidth(proxy.size.width)
          }
          .onChange(of: proxy.size.width) { _, newWidth in
            updateMeasuredWidth(newWidth)
          }
      }
    }
    .onAppear {
      selectedIndex = clamped(selectedIndex)
    }
    .onChange(of: photos.count) { _, _ in
      selectedIndex = clamped(selectedIndex)
    }
  }

  private func updateMeasuredWidth(_ width: CGFloat) {
    let safeWidth = max(120, width)
    guard abs(safeWidth - measuredWidth) > 0.5 else { return }
    measuredWidth = safeWidth
  }
}
