//
//  FirebaseImageStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-23.
//

import UIKit
import FirebaseStorage
import SDWebImageWebPCoder

enum FirebaseImageStore {
  // Point this at your actual bucket. If "scrumblegame-tools" is the bucket
  // itself (not a folder inside the default bucket), keep the gs:// form below.
  private static let storage = Storage.storage(url: "gs://scrumblegame-tools")
  private static let folder = "tools" // adjust if your folder is named differently
  
  enum ImageStoreError: Error { case encodingFailed }
  
  /// Converts PNG data to WebP, uploads it, and returns the public download URL.
  static func uploadWebP(_ pngData: Data, toolName: String) async throws -> String {
    guard let image = UIImage(data: pngData),
          let webpData = SDImageWebPCoder.shared.encodedData(
            with: image,
            format: .webP,
            options: [.encodeCompressionQuality: 0.8]
          )
            else {
      throw ImageStoreError.encodingFailed
    }
    
    let ref = storage.reference().child("\(folder)/\(toolName).webp")
    let metadata = StorageMetadata()
    metadata.contentType = "image/webp"
    
    _ = try await ref.putDataAsync(webpData, metadata: metadata)
    let url = try await ref.downloadURL()
    return url.absoluteString
  }
}
