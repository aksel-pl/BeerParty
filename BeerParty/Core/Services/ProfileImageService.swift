import Foundation
import UIKit
import Supabase

enum ProfileImageError: LocalizedError {
  case invalidImageData
  case unableToCompress
  case imageTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidImageData:
      return "Selected file is not a valid image."
    case .unableToCompress:
      return "Could not compress image. Please choose a different photo."
    case .imageTooLarge:
      return "Image is too large. Please pick a smaller photo."
    }
  }
}

struct ProfileImageService {
  static let maxProfileImageBytes = 300 * 1024
  private let bucketName = "profile_pics"

  func normalizeForUpload(_ rawData: Data) throws -> Data {
    guard let image = UIImage(data: rawData) else {
      throw ProfileImageError.invalidImageData
    }

    let maxDimension: CGFloat = 720
    let resized = resize(image: image, maxDimension: maxDimension)

    var quality: CGFloat = 0.82
    while quality >= 0.35 {
      if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= Self.maxProfileImageBytes {
        return jpeg
      }
      quality -= 0.12
    }

    throw ProfileImageError.imageTooLarge
  }

  func uploadProfileImage(_ imageData: Data, userId: UUID) async throws -> String {
    let path = "\(userId.uuidString)/avatar.jpg"

    _ = try await supabase.storage
      .from(bucketName)
      .upload(
        path,
        data: imageData,
        options: FileOptions(contentType: "image/jpeg", upsert: true)
      )

    return path
  }

  func publicImageURL(for path: String?) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return try? supabase.storage.from(bucketName).getPublicURL(path: path)
  }

  private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
    let originalSize = image.size
    let longestSide = max(originalSize.width, originalSize.height)
    guard longestSide > maxDimension else { return image }

    let scale = maxDimension / longestSide
    let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }
}
