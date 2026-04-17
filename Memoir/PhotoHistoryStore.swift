import Combine
import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers

@MainActor
final class PhotoHistoryStore: ObservableObject {
  @Published var authorizationState: PHAuthorizationStatus = .notDetermined
  @Published var photos: [HistoryPhoto] = []

  private let calendar = Calendar.current
  private let shareMaxImageWidth: CGFloat = 1440
  private let shareJPEGQuality: CGFloat = 0.88
  private let shareMaxCanvasDimension: CGFloat = 8192
  private let shareMaxCanvasPixelCount: CGFloat = 33_000_000

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

  func deletePhoto(localIdentifier: String) async -> Bool {
    guard authorizationState == .authorized || authorizationState == .limited else {
      return false
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
    guard assets.count > 0 else { return false }

    return await withCheckedContinuation { continuation in
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.deleteAssets(assets)
      }) { success, _ in
        continuation.resume(returning: success)
      }
    }
  }

  func prepareShareFile(
    localIdentifier: String,
    title: String,
    subtitle: String,
    footer: String
  ) async -> URL? {
    guard authorizationState == .authorized || authorizationState == .limited else {
      return nil
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
    guard let asset = assets.firstObject else { return nil }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.version = .current
    options.isNetworkAccessAllowed = true

    let result = await withCheckedContinuation {
      (continuation: CheckedContinuation<(Data?, String?), Never>) in
      PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
        data, dataUTI, _, _ in
        continuation.resume(returning: (data, dataUTI))
      }
    }

    guard let data = result.0, let originalImage = UIImage(data: data) else { return nil }

    let normalizedPhoto = normalizedPhotoForShare(originalImage)

    let composedImage = renderShareCard(
      photo: normalizedPhoto,
      title: title,
      subtitle: subtitle,
      footer: footer
    )

    guard let composedData = composedImage.jpegData(compressionQuality: shareJPEGQuality) else {
      return nil
    }

    let fileExtension = UTType.jpeg.preferredFilenameExtension ?? "jpg"

    let tempDir = FileManager.default.temporaryDirectory
    let filename = "memoir-share-\(UUID().uuidString).\(fileExtension)"
    let fileURL = tempDir.appendingPathComponent(filename)

    do {
      try composedData.write(to: fileURL, options: .atomic)
      return fileURL
    } catch {
      return nil
    }
  }

  private func renderShareCard(photo: UIImage, title: String, subtitle: String, footer: String)
    -> UIImage
  {
    let minimumPhotoSize: CGFloat = 1
    let photoPixelSize = CGSize(
      width: max(CGFloat(photo.cgImage?.width ?? Int(photo.size.width)), minimumPhotoSize),
      height: max(CGFloat(photo.cgImage?.height ?? Int(photo.size.height)), minimumPhotoSize)
    )

    // Keep two outer layers around the exact-size image area.
    let outerHorizontalInset: CGFloat = 56
    let topInset: CGFloat = 64
    let titleBlockHeight: CGFloat = 182
    let titleToImageGap: CGFloat = 40
    let imageToFooterGap: CGFloat = 40
    let footerHeight: CGFloat = 80
    let bottomInset: CGFloat = 64

    let cardCornerRadius: CGFloat = 32
    let cardOverlayAlpha: CGFloat = 0.12

    let imageInnerHorizontalInset: CGFloat = 24
    let imageCornerRadius: CGFloat = 0

    let textHorizontalInset: CGFloat = 32
    let titleTopInset: CGFloat = 32
    let titleHeight: CGFloat = 72
    let subtitleTopInset: CGFloat = 120
    let subtitleHeight: CGFloat = 36

    let titleFontSize: CGFloat = 64
    let subtitleFontSize: CGFloat = 32
    let footerFontSize: CGFloat = 32
    let subtitleAlpha: CGFloat = 0.9
    let footerAlpha: CGFloat = 0.78

    let gradientStartLocation: CGFloat = 0
    let gradientEndLocation: CGFloat = 1

    let imageWidth = photoPixelSize.width
    let imageHeight = photoPixelSize.height
    let cardWidth = imageWidth + imageInnerHorizontalInset * 2
    let baseCanvasWidth = cardWidth + outerHorizontalInset * 2
    let baseCanvasHeight =
      topInset + titleBlockHeight + titleToImageGap + imageHeight + imageToFooterGap
      + footerHeight + bottomInset
    let baseCanvasSize = CGSize(width: baseCanvasWidth, height: baseCanvasHeight)

    let dimensionScale = min(1, shareMaxCanvasDimension / max(baseCanvasWidth, baseCanvasHeight))
    let pixelScale = min(
      1,
      sqrt(shareMaxCanvasPixelCount / max(baseCanvasWidth * baseCanvasHeight, 1))
    )
    let renderScale = min(dimensionScale, pixelScale)

    let renderedCanvasSize = CGSize(
      width: max(floor(baseCanvasWidth * renderScale), 1),
      height: max(floor(baseCanvasHeight * renderScale), 1)
    )
    let renderer = UIGraphicsImageRenderer(size: renderedCanvasSize)

    return renderer.image { context in
      let cg = context.cgContext
      if renderScale < 0.999 {
        // Keep existing layout math intact; shrink only final raster size for huge canvases.
        cg.scaleBy(x: renderScale, y: renderScale)
      }
      let bgPair = adaptiveBackgroundColors(from: photo)
      let bgColors = [bgPair.0.cgColor, bgPair.1.cgColor] as CFArray
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: bgColors,
        locations: [gradientStartLocation, gradientEndLocation]
      )
      if let gradient {
        cg.drawLinearGradient(
          gradient,
          start: CGPoint(x: 0, y: 0),
          end: CGPoint(x: baseCanvasSize.width, y: baseCanvasSize.height),
          options: []
        )
      }

      let cardRect = CGRect(
        x: outerHorizontalInset,
        y: topInset,
        width: cardWidth,
        height: baseCanvasSize.height - topInset - bottomInset
      )
      let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cardCornerRadius)
      UIColor.white.withAlphaComponent(cardOverlayAlpha).setFill()
      cardPath.fill()

      let imageTopInset = titleBlockHeight + titleToImageGap
      let imageRect = CGRect(
        x: cardRect.minX + imageInnerHorizontalInset,
        y: cardRect.minY + imageTopInset,
        width: cardRect.width - imageInnerHorizontalInset * 2,
        height: imageHeight
      )

      let imageCardPath = UIBezierPath(roundedRect: imageRect, cornerRadius: imageCornerRadius)
      cg.saveGState()
      imageCardPath.addClip()
      photo.draw(in: imageRect)
      cg.restoreGState()

      let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
        .foregroundColor: UIColor.white,
      ]
      let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: subtitleFontSize, weight: .semibold),
        .foregroundColor: UIColor.white.withAlphaComponent(subtitleAlpha),
      ]
      let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: footerFontSize, weight: .medium),
        .foregroundColor: UIColor.white.withAlphaComponent(footerAlpha),
      ]

      title.draw(
        in: CGRect(
          x: cardRect.minX + textHorizontalInset,
          y: cardRect.minY + titleTopInset,
          width: cardRect.width - textHorizontalInset * 2,
          height: titleHeight
        ),
        withAttributes: titleAttrs
      )
      subtitle.draw(
        in: CGRect(
          x: cardRect.minX + textHorizontalInset,
          y: cardRect.minY + subtitleTopInset,
          width: cardRect.width - textHorizontalInset * 2,
          height: subtitleHeight
        ),
        withAttributes: subtitleAttrs
      )
      footer.draw(
        in: CGRect(
          x: cardRect.minX + textHorizontalInset,
          y: imageRect.maxY + imageToFooterGap,
          width: cardRect.width - textHorizontalInset * 2,
          height: footerHeight
        ),
        withAttributes: footerAttrs
      )
    }
  }

  private func adaptiveBackgroundColors(from photo: UIImage) -> (UIColor, UIColor) {
    let fallbackTop = UIColor(red: 0.12, green: 0.17, blue: 0.28, alpha: 1)
    let fallbackBottom = UIColor(red: 0.06, green: 0.08, blue: 0.13, alpha: 1)

    guard let avg = averageColor(of: photo) else {
      return (fallbackTop, fallbackBottom)
    }

    let top = shade(avg, saturationMultiplier: 0.88, brightnessMultiplier: 0.85)
    let bottom = shade(avg, saturationMultiplier: 1.22, brightnessMultiplier: 0.34)
    return (top, bottom)
  }

  private func shade(
    _ color: UIColor,
    saturationMultiplier: CGFloat,
    brightnessMultiplier: CGFloat
  ) -> UIColor {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
      return UIColor(
        hue: hue,
        saturation: min(max(saturation * saturationMultiplier, 0.06), 0.95),
        brightness: min(max(brightness * brightnessMultiplier, 0.12), 0.9),
        alpha: 1
      )
    }

    var white: CGFloat = 0
    if color.getWhite(&white, alpha: &alpha) {
      return UIColor(white: min(max(white * brightnessMultiplier, 0.12), 0.9), alpha: 1)
    }

    return color
  }

  private func averageColor(of image: UIImage) -> UIColor? {
    guard let cgImage = image.cgImage else { return nil }

    let width = 1
    let height = 1
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    var pixel = [UInt8](repeating: 0, count: bytesPerPixel)

    guard
      let context = CGContext(
        data: &pixel,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return nil
    }

    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let r = CGFloat(pixel[0]) / 255
    let g = CGFloat(pixel[1]) / 255
    let b = CGFloat(pixel[2]) / 255
    let a = CGFloat(pixel[3]) / 255
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }

  private func normalizedPhotoForShare(_ photo: UIImage) -> UIImage {
    let minimumSize: CGFloat = 1
    let sourceSize = CGSize(
      width: max(CGFloat(photo.cgImage?.width ?? Int(photo.size.width)), minimumSize),
      height: max(CGFloat(photo.cgImage?.height ?? Int(photo.size.height)), minimumSize)
    )

    // Width-only policy: extra-tall images are kept if width is within limit.
    let finalScale = min(1, shareMaxImageWidth / sourceSize.width)
    guard finalScale < 0.999 else { return photo }

    let targetSize = CGSize(
      width: max(floor(sourceSize.width * finalScale), minimumSize),
      height: max(floor(sourceSize.height * finalScale), minimumSize)
    )

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    return renderer.image { _ in
      photo.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

}
