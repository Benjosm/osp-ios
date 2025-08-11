import Foundation

class UploadManager: NSObject {
    private let backgroundSession: URLSession
    private var uploadTasks: [String: URLSessionTask] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]

    override init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.osp.upload.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        self.backgroundSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        super.init()
        self.backgroundSession.delegate = self
    }

    /// Starts uploading an item with metadata as multipart form data and calls progress updates
    func upload(item: UploadItem, onProgress: @escaping (Double) -> Void, onCompletion: ((Bool, Error?) -> Void)? = nil) {
        guard let url = URL(string: item.endpoint) else {
            DispatchQueue.main.async {
                onProgress(-1) // Invalid URL
                onCompletion?(false, NSError(domain: "UploadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            }
            return
        }
    
        // Collect metadata for the media item
        let metadata = MetadataCollector.shared.collectMetadata(forMediaId: item.mediaId)
    
        // Build multipart form request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
        // Create the body
        var body = Data()
    
        // Add metadata fields
        for (key, value) in metadata {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
    
        // Add the file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(item.fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: \(mimeType(for: item.fileURL.path))\r\n\r\n")
        do {
            let fileData = try Data(contentsOf: item.fileURL)
            body.append(fileData)
        } catch {
            print("Failed to read file: \(error)")
            DispatchQueue.main.async {
                onProgress(-1)
                onCompletion?(false, error)
            }
            return
        }
    
        // Add final boundary
        body.append("\r\n--\(boundary)--\r\n")
    
        request.httpBody = body
    
        // Assign task identifier for persistence and tracking
        let task = backgroundSession.uploadTask(with: request, fromFile: item.fileURL)
        let taskId = UUID().uuidString
        task.taskDescription = taskId
        uploadTasks[taskId] = task
        progressHandlers[taskId] = onProgress
        
        // Store completion handler
        if let onCompletion = onCompletion {
            completionHandlers[taskId] = onCompletion
        }
        
        task.resume()
    }
    
    // Dictionary to store completion handlers
    private var completionHandlers: [String: (Bool, Error?) -> Void] = [:]
    
    /// Helper to determine MIME type from file extension
    private func mimeType(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
    
        let mimeTypes = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "mov": "video/quicktime",
            "mp4": "video/mp4",
            "heic": "image/heic",
            "heif": "image/heif"
        ]
    
        if let mimeType = mimeTypes[pathExtension.lowercased()] {
            return mimeType
        }
        return "application/octet-stream"
    }
}

extension UploadManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // Handle invalid session
        print("Background session invalid: $error?.localizedDescription ?? "No error")")
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle authentication challenges
        completionHandler(.performDefaultHandling, nil)
    }
}

extension UploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = task.taskDescription else { return }
        
        // Notify progress handler final state
        if let handler = progressHandlers[taskId] {
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
                handler(-1) // Indicate failure
            } else {
                handler(1.0) // Indicate completion
            }
        }
        
        // Call completion handler if one exists
        if let completion = completionHandlers[taskId] {
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }

        // Clean up
        uploadTasks.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        completionHandlers.removeValue(forKey: taskId)
    }
}

extension UploadManager: URLSessionTaskDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let taskId = task.taskDescription,
              let handler = progressHandlers[taskId] else { return }

        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            handler(progress)
        }
    }
}

// MARK: - UploadItem Model
struct UploadItem {
    let mediaId: String
    let fileURL: URL
    let endpoint: String
    let metadata: [String: String]
}
