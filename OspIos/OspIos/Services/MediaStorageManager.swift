import Foundation



/// Media storage operation errors
enum MediaStorageError: Error {
    case storageFailed(Error)
    case invalidMediaType
}

// MARK: - Protocol Definitions (for dependency injection)

/// Manages physical file storage operations in sandbox
protocol StorageManagerProtocol {
    func saveMedia(data: Data, mediaType: MediaType) throws -> URL
    func storeMediaLocally(data: Data, mimeType: String) -> URL?
}

/// Coordinates queued media uploads
protocol UploadQueueManagerProtocol {
    func addMedia(for url: URL)
}

/// Concrete type aliases for dependency injection
typealias StorageManager = StorageManagerProtocol
typealias UploadQueueManager = UploadQueueManagerProtocol

/// Manages temporary storage of media assets in the app sandbox before upload
class MediaStorageManager {
    private let storageManager: StorageManager

    /// Designated initializer
    /// - Parameters:
    ///   - storageManager: Handles low-level file storage operations
    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    /// Converts MediaType to MIME type string
    /// - Parameter mediaType: The media type to convert
    /// - Returns: MIME type string, or nil if conversion fails
    private func getMimeType(from mediaType: MediaType) -> String? {
        switch mediaType {
        case .image:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        }
    }

    /// Stores media data in sandbox storage and queues for upload
    /// - Parameters:
    ///   - data: Media content to persist
    ///   - mediaType: Type of media being stored (image/video)
    ///   - metadata: Metadata associated with the media capture
    ///   - completion: Called with URL of stored media or error
    ///
    /// This implementation:
    /// 1. Saves media using StorageManager (sandbox location)
    /// 2. Reads the saved data and enqueues it with metadata to UploadQueueTask
    /// 3. Returns file URL for reference
    func storeMedia(data: Data, mediaType: MediaType, metadata: Metadata, completion: @escaping (Result<URL, MediaStorageError>) -> Void) {
        guard let mimeType = getMimeType(from: mediaType) else {
            completion(.failure(.invalidMediaType))
            return
        }

        guard let fileURL = storageManager.storeMediaLocally(data: data, mimeType: mimeType) else {
            completion(.failure(.storageFailed(NSError(domain: "MediaStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to store media locally"]))))
            return
        }

        // Add to upload queue with metadata using original data
        let success = UploadQueueTask.shared.enqueue(media: data, metadata: metadata)
        if !success {
            print("Warning: Failed to enqueue media for upload")
        }

        completion(.success(fileURL))
    }
}
