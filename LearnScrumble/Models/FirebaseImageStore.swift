//
//  FirebaseImageStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-23.
//

import UIKit
import FirebaseStorage
import SDWebImageWebPCoder

// MARK: - Flow of this file
// Saves newly generated word images to Firebase Storage, so other users reuse them instead of paying for a new one.
//   RequestModel.resolveImage -> uploadWebP(pngData, toolName)
//     -> await encodeWebP(pngData) [background thread]: PNG -> smaller WebP
//     -> upload to "tools/<toolName>.webp" -> return its download URL
//   -> FirebaseWordStore.saveIfNeeded stores that URL in the word's Firestore doc.

enum FirebaseImageStore {
  // Point this at your actual bucket. If "scrumblegame-tools" is the bucket
  // itself (not a folder inside the default bucket), keep the gs:// form below.
  
  // Debug (Run in Xcode) → dev project's default bucket, taken from the dev plist.
  // Release (Archive) → the production bucket "scrumblegame-tools".
  #if DEBUG
    private static let storage = Storage.storage()
  #else
    private static let storage = Storage.storage(url: "gs://scrumblegame-tools")
  #endif
  private static let folder = "tools" // adjust if your folder is named differently
  
  enum ImageStoreError: Error { case encodingFailed }              // PNG couldn't be turned into WebP
  
  // MARK: - uploadWebP
  // Converts PNG data to WebP, uploads it, and returns the public download URL.
  // 1. Heavy conversion runs on a background thread (encodeWebP) — the loading animation keeps moving.
  //    Conversion failed -> throws encodingFailed (the caller still uses the PNG this session).
  // 2. Uploads to "tools/<toolName>.webp", marked as image/webp.
  // 3. Asks Storage for the file's download URL and returns it as text.
  static func uploadWebP(_ pngData: Data, toolName: String) async throws -> String {
    guard let webpData = await encodeWebP(pngData) else {
      throw ImageStoreError.encodingFailed
    }

    let ref = storage.reference().child("\(folder)/\(toolName).webp")
    let metadata = StorageMetadata()
    metadata.contentType = "image/webp"
    
    _ = try await ref.putDataAsync(webpData, metadata: metadata)
    let url = try await ref.downloadURL()
    return url.absoluteString
  }

  // MARK: - encodeWebP (background)
  // Flow: RequestModel.resolveImage -> uploadWebP(pngData) -> await encodeWebP(pngData) [background thread]
  //       -> WebP bytes come back on the main thread -> uploadWebP uploads them to Firebase Storage
  // PNG -> WebP. Decodes the full 1024×1024 image and re-compresses it: a few hundred ms of CPU,
  // so it runs on a background thread instead of freezing the main thread.
  //   @concurrent  — run this on a background thread, not the caller's (main) thread
  //   nonisolated  — allowed off the main thread; touches no UI or app state
  // Steps: PNG bytes -> UIImage (nil if the bytes aren't a real image) -> WebP bytes at 80% quality (smaller upload, still sharp).
  // Called from: uploadWebP above. Returns nil if the bytes aren't an image or encoding fails.
  @concurrent
  nonisolated private static func encodeWebP(_ pngData: Data) async -> Data? {
    guard let image = UIImage(data: pngData) else { return nil }
    return SDImageWebPCoder.shared.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: 0.8])
  }
}
