import Photos
import SwiftUI

struct HistoryDetailPageView: View {
  let photo: HistoryPhoto
  @State private var showOriginalViewer = false

  var body: some View {
    AssetImageView(
      assetIdentifier: photo.id,
      targetSize: CGSize(width: 2600, height: 2600),
      contentMode: .aspectFit
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .id(photo.id)
    .onTapGesture {
      showOriginalViewer = true
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .fullScreenCover(isPresented: $showOriginalViewer) {
      FullScreenOriginalPhotoView(assetIdentifier: photo.id)
    }
  }
}

struct FullScreenOriginalPhotoView: View {
  let assetIdentifier: String

  @Environment(\.dismiss) private var dismiss
  @State private var scale: CGFloat = 1
  @State private var lastScaleValue: CGFloat = 1

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      OriginalAssetImageView(assetIdentifier: assetIdentifier)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .scaleEffect(scale)
        .gesture(
          MagnificationGesture()
            .onChanged { value in
              let delta = value / lastScaleValue
              lastScaleValue = value
              scale = min(max(scale * delta, 1), 5)
            }
            .onEnded { _ in
              lastScaleValue = 1
              if scale < 1.02 {
                scale = 1
              }
            }
        )
        .onTapGesture(count: 2) {
          withAnimation(.easeInOut(duration: 0.2)) {
            scale = scale > 1.2 ? 1 : 2
          }
        }
    }
    .overlay(alignment: .topTrailing) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 28))
          .foregroundStyle(.white.opacity(0.92))
          .padding(18)
      }
    }
  }
}

struct OriginalAssetImageView: View {
  let assetIdentifier: String

  @State private var image: UIImage?
  @State private var requestID: PHImageRequestID?
  @State private var requestToken = UUID()

  private let manager = PHCachingImageManager()

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
      } else {
        ProgressView()
          .tint(.white)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .task(id: assetIdentifier) {
      loadOriginalImage()
    }
    .onDisappear {
      cancelRequest()
    }
  }

  private func loadOriginalImage() {
    cancelRequest()
    image = nil
    let token = UUID()
    requestToken = token

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else { return }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.isNetworkAccessAllowed = true

    requestID = manager.requestImage(
      for: asset,
      targetSize: PHImageManagerMaximumSize,
      contentMode: .aspectFit,
      options: options
    ) { fetchedImage, info in
      guard token == requestToken else { return }
      if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
        return
      }
      if info?[PHImageErrorKey] != nil {
        return
      }
      if let fetchedImage {
        image = fetchedImage
      }
    }
  }

  private func cancelRequest() {
    if let requestID {
      manager.cancelImageRequest(requestID)
    }
    requestID = nil
    requestToken = UUID()
  }
}

struct AssetImageView: View {
  let assetIdentifier: String
  let targetSize: CGSize
  let contentMode: PHImageContentMode

  @State private var image: UIImage?
  @State private var requestID: PHImageRequestID?
  @State private var requestToken = UUID()

  private let manager = PHCachingImageManager()

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.gray.opacity(0.16))

      if let image {
        if contentMode == .aspectFill {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
        } else {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
        }
      } else {
        ProgressView()
      }
    }
    .task(id: assetIdentifier) {
      loadImage()
    }
    .onDisappear {
      cancelRequest()
    }
  }

  private func loadImage() {
    cancelRequest()
    image = nil
    let token = UUID()
    requestToken = token

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else { return }

    let options = PHImageRequestOptions()
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true

    requestID = manager.requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: contentMode,
      options: options
    ) { fetchedImage, info in
      guard token == requestToken else { return }
      if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
        return
      }
      if info?[PHImageErrorKey] != nil {
        return
      }
      if let fetchedImage {
        image = fetchedImage
      }
    }
  }

  private func cancelRequest() {
    if let requestID {
      manager.cancelImageRequest(requestID)
    }
    requestID = nil
    requestToken = UUID()
  }
}
