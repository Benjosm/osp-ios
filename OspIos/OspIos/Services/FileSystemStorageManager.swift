import Foundation

/// Concrete implementation of StorageManagerProtocol using FileManager
class FileSystemStorageManager: StorageManagerProtocol {
    private let fileManager: FileManager
    private let cacheDirectory: URL

    /// Initializes the storage manager with custom file manager (for testing) or defaults to defaultManager
    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        // Use Caches directory to avoid iCloud backup
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let directory = cachesDir?.appendingPathComponent("Media", isDirectory: true) else {
            throw MediaStorageError.storageFailed(NSError(domain: "FileSystemStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create media directory URL"]))
        }
        self.cacheDirectory = directory

        // Create Media directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
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
}
