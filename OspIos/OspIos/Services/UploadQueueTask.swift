import Foundation

// Struct to represent an item in the upload queue
struct UploadQueueItem: Codable {
    let id: UUID
    let mediaData: Data
    let metadata: Metadata
    let createdAt: Date
    var status: UploadStatus
    
    init(mediaData: Data, metadata: Metadata, status: UploadStatus = .pending) {
        self.id = UUID()
        self.mediaData = mediaData
        self.metadata = metadata
        self.createdAt = Date()
        self.status = status
    }
}

// Enum to represent upload status
enum UploadStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
}

// MARK: - Codable support for Metadata
extension Metadata: Codable {
    enum CodingKeys: String, CodingKey {
        case captureTime
        case latitude
        case longitude
        case orientation
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(captureTime, forKey: .captureTime)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(orientation.rawValue, forKey: .orientation)
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        captureTime = try values.decode(Date.self, forKey: .captureTime)
        latitude = try values.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try values.decodeIfPresent(Double.self, forKey: .longitude)
        let orientationRawValue = try values.decode(Int.self, forKey: .orientation)
        orientation = UIDeviceOrientation(rawValue: orientationRawValue) ?? .unknown
    }
}

// MARK: - Data persistence support
extension Data {
    static func loadFromFile<T: Codable>(_ filename: String) -> T? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = (documentsPath as NSString).appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: filePath) else { return nil }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Error loading data from file: $error)")
            return nil
        }
    }
    
    func saveToFile(_ filename: String) -> Bool {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = (documentsPath as NSString).appendingPathComponent(filename)
        
        do {
            try self.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            return true
        } catch {
            print("Error saving data to file: $error)")
            return false
        }
    }
}

// Manages the queue of media items to be uploaded
class UploadQueueTask {
    // Shared instance for singleton pattern
    static let shared = UploadQueueTask()
    
    // Private queue to store upload items
    private var uploadQueue: [UploadQueueItem] = []
    
    // Queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.osp.upload.queue", attributes: .concurrent)
    
    // Private initializer for singleton pattern
    private init() {}
    
    // Add a media item to the upload queue with metadata
    // Returns true if the item was added (not a duplicate), false otherwise
    @discardableResult
    func enqueue(media: Data, metadata: Metadata) -> Bool {
        // Create a unique hash of the item for duplicate checking
        // We'll use media size and timestamp for now, as metadata contains non-hashable types
        let newItemHash = "\(media.count)_\(Int(metadata.captureTime.timeIntervalSince1970))"
        
        var isDuplicate = false
        
        // Read queue to check for duplicates
        queue.sync {
            isDuplicate = uploadQueue.contains { item in
                let itemHash = "\(item.mediaData.count)_\(Int(item.metadata.captureTime.timeIntervalSince1970))"
                return itemHash == newItemHash
            }
        }
        
        // If it's a duplicate, don't add it
        if isDuplicate {
            print("Duplicate item detected, not adding to queue")
            return false
        }
        
        // Create new item and add to queue
        let newItem = UploadQueueItem(mediaData: media, metadata: metadata)
        
        queue.async(flags: .barrier) {
            self.uploadQueue.append(newItem)
            print("Added item to upload queue. Queue size: \(self.uploadQueue.count)")
        }
        
        // Save the updated queue to persistent storage
        saveQueueToPersistentStorage()
        
        return true
    }
    
    // MARK: - Persistence Methods
    private func saveQueueToPersistentStorage() {
        // Convert the queue to data
        guard let encodedData = try? JSONEncoder().encode(uploadQueue) else {
            print("Failed to encode upload queue")
            return
        }
        
        // Save to file
        let filename = "upload_queue.json"
        if !encodedData.saveToFile(filename) {
            print("Failed to save upload queue to persistent storage")
        }
    }
    
    private func loadQueueFromPersistentStorage() {
        let filename = "upload_queue.json"
        guard let savedQueue = [UploadQueueItem].loadFromFile(filename) else {
            print("No saved queue found, starting with empty queue")
            return
        }
        
        queue.async(flags: .barrier) {
            self.uploadQueue = savedQueue
            print("Loaded \(savedQueue.count) items from persistent storage")
        }
    }
    
    // Get all items in the queue (for processing/uploads)
    func getUploadItems() -> [UploadQueueItem] {
        var items: [UploadQueueItem] = []
        queue.sync {
            items = uploadQueue
        }
        return items
    }
    
    // Remove an item from the queue after successful upload
    func removeItem(withId id: UUID) {
        queue.async(flags: .barrier) {
            self.uploadQueue.removeAll { $0.id == id }
            print("Removed item from upload queue. Remaining items: \(self.uploadQueue.count)")
        }
    }
    
    // Clear all items from the queue
    func clearQueue() {
        queue.async(flags: .barrier) {
            let count = self.uploadQueue.count
            self.uploadQueue.removeAll()
            print("Cleared upload queue. Removed \(count) items")
        }
    }
    
    // Get the current size of the queue
    func queueSize() -> Int {
        var size = 0
        queue.sync {
            size = self.uploadQueue.count
        }
        return size
    }
}
