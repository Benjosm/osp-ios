import Foundation

// Struct to represent an item in the upload queue
struct UploadQueueItem {
    let id: UUID
    let mediaData: Data
    let metadata: [String: Any]
    let createdAt: Date
    
    init(mediaData: Data, metadata: [String: Any]) {
        self.id = UUID()
        self.mediaData = mediaData
        self.metadata = metadata
        self.createdAt = Date()
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
    func enqueue(media: Data, metadata: [String: Any]) -> Bool {
        // Create a dictionary representation of the item for duplicate checking
        let newItemHash = "\(media.count)_\(metadata)"
        
        var isDuplicate = false
        
        // Read queue to check for duplicates
        queue.sync {
            isDuplicate = uploadQueue.contains { item in
                let itemHash = "\(item.mediaData.count)_\(item.metadata)"
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
        
        return true
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
