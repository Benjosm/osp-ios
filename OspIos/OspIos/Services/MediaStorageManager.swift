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
    private let uploadQueue: UploadQueueManager
    
    /// Designated initializer
    /// - Parameters:
    ///   - storageManager: Handles low-level file storage operations
    ///   - uploadQueue: Coordinates media upload tasks
    init(storageManager: StorageManager, uploadQueue: UploadQueueManager) {
        self.storageManager = storageManager
        self.uploadQueue = uploadQueue
    }
    
    /// Stores media data in sandbox storage and queues for upload
    /// - Parameters:
    ///   - data: Media content to persist
    ///   - mediaType: Type of media being stored (image/video)
    ///   - completion: Called with URL of stored media or error
    ///
    /// This implementation:
    /// 1. Saves media using StorageManager (sandbox location)
    /// 2. Adds file to upload queue upon successful storage
    /// 3. Returns file URL for upload reference
    func storeMedia(data: Data, mediaType: MediaType, completion: @escaping (Result<URL, MediaStorageError>) -> Void) {
        do {
            // Store media in sandbox storage
            let fileURL = try storageManager.saveMedia(data: data, mediaType: mediaType)
            
            // Register with upload system
            uploadQueue.addMedia(for: fileURL)
            
            completion(.success(fileURL))
        } catch {
            completion(.failure(.storageFailed(error)))
        }
    }
}
