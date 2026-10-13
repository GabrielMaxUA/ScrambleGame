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
    guard let webpData = await encodeWebP(pngData) else {          // heavy part runs on a background thread — the loading animation keeps moving
      throw ImageStoreError.encodingFailed
    }

    let ref = storage.reference().child("\(folder)/\(toolName).webp")
    let metadata = StorageMetadata()
    metadata.contentType = "image/webp"
    
    _ = try await ref.putDataAsync(webpData, metadata: metadata)
    let url = try await ref.downloadURL()
    return url.absoluteString
  }

  // MARK: - Background WebP encoding
  // Flow: RequestModel.resolveImage -> uploadWebP(pngData) -> await encodeWebP(pngData) [background thread]
  //       -> WebP bytes come back on the main thread -> uploadWebP uploads them to Firebase Storage

  /// PNG -> WebP. Decodes the full 1024×1024 image and re-compresses it: a few hundred ms of CPU,
  /// so it runs on a background thread (@concurrent) instead of freezing the main thread.
  /// Called from: uploadWebP above. Returns nil if the bytes aren't an image or encoding fails.
  @concurrent                                                      // run this on a background thread, not the caller's (main) thread
  nonisolated private static func encodeWebP(_ pngData: Data) async -> Data? {   // nonisolated: allowed off the main thread — touches no UI or app state
    guard let image = UIImage(data: pngData) else { return nil }  // PNG bytes from GPT -> UIImage (fails if the bytes aren't a real image)
    return SDImageWebPCoder.shared.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: 0.8])   // UIImage -> WebP bytes at 80% quality (smaller upload, still sharp)
  }
}
