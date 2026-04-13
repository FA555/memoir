import SwiftUI

struct HistoryDetailPagerView: View {
  let photos: [HistoryPhoto]
  @Binding var selectedIndex: Int
  let onDeleteCurrent: (String) async -> Void

  @State private var presentedImageHeight: CGFloat = 320
  @State private var showingDeletePopover = false
  @State private var pendingDeletePhotoID: String?

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

        HStack {
          Spacer()

          Button(role: .destructive) {
            pendingDeletePhotoID = currentPhoto.id
            showingDeletePopover = true
          } label: {
            Image(systemName: "trash")
              .font(.title3.weight(.semibold))
              .foregroundStyle(.red)
              .frame(width: 44, height: 44)
              .background(.thinMaterial, in: Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("accessibility.delete_photo")
          .popover(isPresented: $showingDeletePopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
              Text("dialog.delete_photo_title")
                .font(.headline)

              Button("button.delete_photo", role: .destructive) {
                guard let pendingDeletePhotoID else { return }
                showingDeletePopover = false
                Task {
                  await onDeleteCurrent(pendingDeletePhotoID)
                  self.pendingDeletePhotoID = nil
                }
              }
              .buttonStyle(.glass)
              .foregroundStyle(.red)
            }
            .padding(14)
            .frame(minWidth: 220)
            .presentationCompactAdaptation(.popover)
          }
          .padding(.trailing, 16)
        }
        .padding(.top, 6)
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
    // Give GeometryReader a stable intrinsic height inside ScrollView to prevent scroll lock.
    .frame(height: presentedImageHeight + 128)
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
