import Foundation

/// Delegate protocol for UploadQueue events
protocol UploadQueueDelegate: AnyObject {
    func uploadQueue(_ queue: UploadQueue, didStartUploadForMediaId mediaId: String)
    func uploadQueue(_ queue: UploadQueue, didUpdateProgress mediaId: String, progress: Double)
    func uploadQueue(_ queue: UploadQueue, didFinishUploadForMediaId mediaId: String, success: Bool, error: Error?)
    func uploadQueueDidResume(_ queue: UploadQueue)
}

/// Manages a serial queue of uploads with persistence and retry capabilities
class UploadQueue {
    // MARK: - Properties
    
    private let operationQueue: OperationQueue
    private var uploadOperations: [String: UploadOperation] = [:] // mediaId -> operation
    private let uploadManager: UploadManager
    private let persistenceKey = "UploadQueue_PersistentState"
    private var backgroundSessionCompletionHandler: (() -> Void)?
    
    weak var delegate: UploadQueueDelegate?
    
    // MARK: - Initialization
    
    init(uploadManager: UploadManager = UploadManager()) {
        self.uploadManager = uploadManager
        self.operationQueue = OperationQueue()
        
        // Configure serial execution (max 1 concurrent operation)
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.name = "com.osp.upload.queue"
        
        // Restore any pending uploads from previous sessions
        restoreFromPersistence()
    }
    
    // MARK: - Background Session Handling
    
    /// Call this method from application(_:handleEventsForBackgroundURLSession:completionHandler:)
    /// to reconnect to ongoing background uploads
    func handleBackgroundSessionEvents(completionHandler: @escaping () -> Void) {
        self.backgroundSessionCompletionHandler = completionHandler
        
        // The UploadManager's delegate will handle the actual events
        // We just need to keep the completion handler until it's called
    }
    
    /// Call this when background session events have been fully processed
    func completeBackgroundSession() {
        backgroundSessionCompletionHandler?()
        backgroundSessionCompletionHandler = nil
    }
    
    deinit {
        // Ensure state is saved when queue is deallocated
        saveToPersistence()
    }
    
    // MARK: - Queue Management
    
    /// Adds an upload to the queue
    /// - Returns: True if successfully added, false if already in queue or invalid
    func addUpload(mediaId: String) -> Bool {
        // Check if already in queue
        guard !uploadOperations.keys.contains(mediaId) else {
            return false
        }
        
        // Resolve file URL from media ID
        let storageResolver = LocalMediaStorageTask()
        guard let fileURL = storageResolver.fileURL(forMediaId: mediaId) else {
            print("Media not found for ID: \(mediaId)")
            return false
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Media file does not exist at path: \(fileURL.path)")
            return false
        }
        
        // Create upload item
        let metadata = MetadataCollector.shared.collectMetadata(forMediaId: mediaId)
        let uploadItem = UploadItem(
            mediaId: mediaId,
            fileURL: fileURL,
            endpoint: "https://api.osp.dev/upload", // Placeholder endpoint
            metadata: metadata
        )
        
        // Create operation with progress and completion handlers
        let operation = UploadOperation(uploadItem: uploadItem, uploadManager: uploadManager) { [weak self] progress in
            guard progress >= 0 else {
                // Upload failed
                return
            }
            self?.delegate?.uploadQueue(self!, didUpdateProgress: mediaId, progress: progress)
        } completion: { [weak self] success, error in
            self?.delegate?.uploadQueue(self!, didFinishUploadForMediaId: mediaId, success: success, error: error)
        }
        
        // Store operation and add to queue
        uploadOperations[mediaId] = operation
        operation.completionBlock = { [weak self] in
            // Clean up completed operation
            self?.uploadOperations.removeValue(forKey: mediaId)
        }
        
        // Notify delegate
        delegate?.uploadQueue(self, didStartUploadForMediaId: mediaId)
        
        // Add to operation queue
        operationQueue.addOperation(operation)
        
        // Persist state
        saveToPersistence()
        
        return true
    }
    
    /// Cancels all pending uploads
    func cancelAllUploads() {
        operationQueue.cancelAllOperations()
        uploadOperations.removeAll()
        saveToPersistence()
    }
    
    /// Checks if a specific media upload is currently in the queue
    func hasPendingUpload(forMediaId mediaId: String) -> Bool {
        return uploadOperations.keys.contains(mediaId) || isUploadInProgress(mediaId: mediaId)
    }
    
    /// Checks if a specific upload is currently in progress
    func isUploadInProgress(mediaId: String) -> Bool {
        // We need to check with UploadManager if this task is currently being uploaded
        // This requires modifications to UploadManager to track active uploads
        return false // Placeholder - will be implemented later
    }
    
    /// Gets the current number of pending uploads (not including in-progress)
    var pendingUploadCount: Int {
        return uploadOperations.count
    }
    
    /// Gets the current progress of the in-progress upload, if any
    var currentProgress: Double? {
        // This will require coordination with UploadManager
        // Placeholder implementation
        return nil
    }
    
    // MARK: - Persistence
    
    /// Saves the current queue state to UserDefaults
    private func saveToPersistence() {
        var persistentData: [[String: Any]] = []
        
        // Save all pending operations
        for (mediaId, operation) in uploadOperations {
            if let representation = operation.persistentRepresentation()["mediaId"] as? String,
               representation == mediaId {
                persistentData.append(operation.persistentRepresentation())
            }
        }
        
        // Store in UserDefaults
        if let encoded = try? JSONSerialization.data(withJSONObject: persistentData) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }
    
    /// Restores the queue state from UserDefaults
    private func restoreFromPersistence() {
        guard let savedData = UserDefaults.standard.data(forKey: persistenceKey),
              let jsonArray = try? JSONSerialization.jsonObject(with: savedData) as? [[String: Any]] else {
            return
        }
        
        // Restore each operation
        for operationData in jsonArray {
            guard let mediaId = operationData["mediaId"] as? String else { continue }
            
            // Create operation from persistent data
            if let operation = UploadOperation.fromPersistentRepresentation(
                operationData,
                uploadManager: uploadManager
            ) { 
                // Set up progress and completion handlers for restored operation
                operation.onProgress = { [weak self] progress in
                    guard progress >= 0, let self = self else { return }
                    self.delegate?.uploadQueue(self, didUpdateProgress: mediaId, progress: progress)
                }
                
                operation.onCompletion = { [weak self] success, error in
                    guard let self = self else { return }
                    self.delegate?.uploadQueue(self, didFinishUploadForMediaId: mediaId, success: success, error: error)
                }
                
                operation.completionBlock = { [weak self] in
                    self?.uploadOperations.removeValue(forKey: mediaId)
                }
                
                // Add to our tracking dictionary (it will be added to queue when app resumes)
                uploadOperations[mediaId] = operation
            }
        }
        
        // Re-add all restored operations to the queue
        for operation in uploadOperations.values {
            operationQueue.addOperation(operation)
        }
        
        if !uploadOperations.isEmpty {
            delegate?.uploadQueueDidResume(self)
        }
    }
}
