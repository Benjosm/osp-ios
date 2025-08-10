import Foundation

/// Concrete implementation of StorageManagerProtocol using FileManager
class FileSystemStorageManager: StorageManagerProtocol {
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let temporaryDirectory: URL

    /// Initializes the storage manager with custom file manager (for testing) or defaults to defaultManager
    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        // Use Caches directory to avoid iCloud backup for existing functionality
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let directory = cachesDir?.appendingPathComponent("Media", isDirectory: true) else {
            throw MediaStorageError.storageFailed(NSError(domain: "FileSystemStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create media directory URL"]))
        }
        self.cacheDirectory = directory

        // Create Media directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }

        // Get the temporary directory
        self.temporaryDirectory = fileManager.temporaryDirectory
    }

    /// Saves media data to the app's cache directory with a unique filename
    /// - Parameters:
    ///   - data: The media content to write
    ///   - mediaType: The type of media, used to determine file extension
    /// - Returns: The URL where the file was saved
    /// - Throws: MediaStorageError.storageFailed on write error
    func saveMedia(data: Data, mediaType: MediaType) throws -> URL {
        let fileExtension = mediaType == .image ? "jpg" : "mp4"
        let uniqueName = "\(UUID().uuidString).\(fileExtension)"
        let fileURL = cacheDirectory.appendingPathComponent(uniqueName)

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw MediaStorageError.storageFailed(error)
        }
    }

    /// Stores media data in the temporary directory with a unique filename
    /// - Parameters:
    ///   - data: Media content to persist
    ///   - mimeType: MIME type of the media (e.g., "image/jpeg", "video/mp4")
    /// - Returns: URL of the stored file if successful, nil otherwise
    ///
    /// This method:
    /// 1. Determines file extension from MIME type
    /// 2. Generates a unique filename using UUID
    /// 3. Writes data to temporary directory
    /// 4. Returns the file URL or nil on failure
    func storeMediaLocally(data: Data, mimeType: String) -> URL? {
        // Extract file extension from MIME type
        let fileExtension: String
        switch mimeType.lowercased() {
        case let type where type.contains("image/jpeg"), let type where type.contains("image/jpg"):
            fileExtension = "jpg"
        case let type where type.contains("image/png"):
            fileExtension = "png"
        case let type where type.contains("video/mp4"):
            fileExtension = "mp4"
        default:
            return nil // Unsupported MIME type
        }

        // Generate unique filename
        let uniqueName = "\(UUID().uuidString).\(fileExtension)"
        let fileURL = temporaryDirectory.appendingPathComponent(uniqueName)

        // Write data to file
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Failed to write media to temporary directory: \(error)")
            return nil
        }
    }
}
