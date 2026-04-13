import Combine
import Foundation
import Photos

@MainActor
final class PhotoHistoryStore: ObservableObject {
  @Published var authorizationState: PHAuthorizationStatus = .notDetermined
  @Published var photos: [HistoryPhoto] = []

  private let calendar = Calendar.current

  func ensureAuthorizationAndLoad(month: Int, day: Int) async {
    authorizationState = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    if authorizationState == .notDetermined {
      authorizationState = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    await loadPhotos(month: month, day: day)
  }

  func loadPhotos(month: Int, day: Int) async {
    guard authorizationState == .authorized || authorizationState == .limited else {
      photos = []
      return
    }

    let loaded = await Task.detached(priority: .userInitiated) { [calendar] in
      var result: [HistoryPhoto] = []
      let options = PHFetchOptions()
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

      let assets = PHAsset.fetchAssets(with: .image, options: options)
      assets.enumerateObjects { asset, _, stop in
        guard let createdAt = asset.creationDate else { return }
        if calendar.component(.month, from: createdAt) == month
          && calendar.component(.day, from: createdAt) == day
        {
          result.append(
            HistoryPhoto(
              id: asset.localIdentifier,
              creationDate: createdAt,
              pixelWidth: asset.pixelWidth,
              pixelHeight: asset.pixelHeight
            )
          )
        }

        if result.count >= 300 {
          stop.pointee = true
        }
      }
      return result.sorted { $0.creationDate > $1.creationDate }
    }.value

    photos = loaded
  }
}
