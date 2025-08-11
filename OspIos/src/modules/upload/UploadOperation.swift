import Foundation

/// Operation that handles a single upload with retry logic
class UploadOperation: Operation {
    private let uploadItem: UploadItem
    private let uploadManager: UploadManager
    private let maxRetries: Int = 3
    private var retryCount: Int = 0
    private var onProgress: ((Double) -> Void)?
    private var onCompletion: ((Bool, Error?) -> Void)?
    
    init(uploadItem: UploadItem, uploadManager: UploadManager, onProgress: ((Double) -> Void)? = nil, onCompletion: ((Bool, Error?) -> Void)? = nil) {
        self.uploadItem = uploadItem
        self.uploadManager = uploadManager
        self.onProgress = onProgress
        self.onCompletion = onCompletion
    }
    
    override func main() {
        // If operation is cancelled, don't start
        guard !isCancelled else { return }
        
        // Perform the upload
        performUpload()
    }
    
    private func performUpload() {
        var shouldRetry = false
        var lastError: Error?
        
        let progressHandler: (Double) -> Void = { [weak self] progress in
            // If operation is cancelled, don't report progress
            guard !self?.isCancelled ?? true else { return }
            self?.onProgress?(progress)
        }
        
        let uploadComplete = { [weak self] (success: Bool, error: Error?) in
            guard let self = self, !self.isCancelled else { return }
            
            if success {
                // Upload succeeded
                self.onCompletion?(true, nil)
            } else {
                // Upload failed
                lastError = error
                shouldRetry = self.shouldAttemptRetry()
                
                if shouldRetry {
                    self.scheduleRetry()
                } else {
                    self.onCompletion?(false, error)
                }
            }
        }
        
        // Call upload manager
        if !isCancelled {
            uploadManager.upload(item: uploadItem, onProgress: progressHandler, onCompletion: { [weak self] success, error in
                guard let self = self, !self.isCancelled else { return }
                uploadComplete(success, error)
            })
        }
    }
    
    private func shouldAttemptRetry() -> Bool {
        return retryCount < maxRetries
    }
    
    private func scheduleRetry() {
        retryCount += 1
        
        // Calculate exponential backoff delay (2^retryCount seconds)
        let delay = pow(2.0, Double(retryCount))
        let when = DispatchTime.now() + .seconds(Int(delay))
        
        DispatchQueue.global().asyncAfter(deadline: when) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.performUpload()
        }
    }
    
    // MARK: - Persistence
    
    /// Creates a dictionary representation for persistence
    func persistentRepresentation() -> [String: Any] {
        return [
            "mediaId": uploadItem.mediaId,
            "fileURL": uploadItem.fileURL.absoluteString,
            "endpoint": uploadItem.endpoint,
            "retryCount": retryCount,
            "createdAt": Date().timeIntervalSinceReferenceDate
        ]
    }
    
    /// Creates an UploadOperation from a persistent representation
    static func fromPersistentRepresentation(_ data: [String: Any], uploadManager: UploadManager, onProgress: ((Double) -> Void)? = nil, onCompletion: ((Bool, Error?) -> Void)? = nil) -> UploadOperation? {
        guard
            let mediaId = data["mediaId"] as? String,
            let fileURLString = data["fileURL"] as? String,
            let fileURL = URL(string: fileURLString),
            let endpoint = data["endpoint"] as? String,
            let retryCount = data["retryCount"] as? Int
        else {
            return nil
        }
        
        // Reconstruct UploadItem
        let metadata = MetadataCollector.shared.collectMetadata(forMediaId: mediaId)
        let uploadItem = UploadItem(
            mediaId: mediaId,
            fileURL: fileURL,
            endpoint: endpoint,
            metadata: metadata
        )
        
        let operation = UploadOperation(
            uploadItem: uploadItem,
            uploadManager: uploadManager,
            onProgress: onProgress,
            onCompletion: onCompletion
        )
        
        // Restore retry count
        operation.retryCount = retryCount
        
        return operation
    }
}
