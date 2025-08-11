import Foundation

/// Protocol for resolving a media ID to a local file URL
protocol MediaStorageResolving {
    func fileURL(forMediaId mediaId: String) -> URL?
}

/// Concrete implementation that maps media IDs to local file paths
class LocalMediaStorageTask: MediaStorageResolving {
    private let cacheDirectory: URL

    init(cacheDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!) {
        self.cacheDirectory = cacheDirectory
    }

    func fileURL(forMediaId mediaId: String) -> URL? {
        let fileName = "media_$mediaId.data"
        return cacheDirectory.appendingPathComponent(fileName)
    }
}

/// Coordinates the upload of media by ID, including file resolution and metadata collection
import UIKit

class MediaUploadCoordinator {
    private let storageResolver: MediaStorageResolving
    private let metadataCollector: MetadataCollector
    private let uploadManager: UploadManager
    private let trustScoreCalculator: TrustScoreCalculationTask
    private weak var presentingViewController: UIViewController?

    init(
        storageResolver: MediaStorageResolving = LocalMediaStorageTask(),
        metadataCollector: MetadataCollector = MetadataCollector(),
        uploadManager: UploadManager = UploadManager(),
        trustScoreCalculator: TrustScoreCalculationTask = TrustScoreCalculationTask(),
        presentingViewController: UIViewController? = nil
    ) {
        self.storageResolver = storageResolver
        self.metadataCollector = metadataCollector
        self.uploadManager = uploadManager
        self.trustScoreCalculator = trustScoreCalculator
        self.presentingViewController = presentingViewController
    }

    /// Initiates upload for a given mediaId
    func uploadMedia(withId mediaId: String, onProgress: @escaping (Double) -> Void, onCompletion: ((Bool) -> Void)? = nil) {
        // Resolve file URL from media ID
        guard let fileURL = storageResolver.fileURL(forMediaId: mediaId) else {
            print("Media not found for ID: $mediaId)")
            onProgress(-1) // Indicate failure
            onCompletion?(false)
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Media file does not exist at path: $fileURL.path)")
            onProgress(-1)
            onCompletion?(false)
            return
        }

        // Collect metadata
        let metadata = metadataCollector.collectMetadata(forMediaId: mediaId)

        // Create upload item
        let uploadItem = UploadItem(
            mediaId: mediaId,
            fileURL: fileURL,
            endpoint: "https://api.osp.dev/upload", // Placeholder endpoint
            metadata: metadata
        )

        // Record start time for upload duration measurement
        let uploadStartTime = Date()

        // Start upload with progress and completion handling
        uploadManager.upload(item: uploadItem, onProgress: { progress in
            DispatchQueue.main.async {
                // Update progress in UI if valid
                if progress >= 0.0 && progress <= 1.0 {
                    onProgress(progress)
                } else {
                    // Error case
                    onProgress(progress)
                    onCompletion?(false)
                }
            }
        }, onCompletion: { success, error in
            DispatchQueue.main.async {
                if success {
                    // Calculate upload time
                    let uploadTime = Date().timeIntervalSince(uploadStartTime)
                    
                    // Calculate trust score
                    let trustScore = self.trustScoreCalculator.calculateTrustScore(forMediaId: mediaId)
                    
                    // Present confirmation view if we have a presenting view controller
                    if let presentingVC = self.presentingViewController {
                        let confirmationView = ConfirmationView(
                            trustScore: trustScore,
                            uploadTime: uploadTime
                        )
                        let hostingController = UIHostingController(rootView: confirmationView)
                        hostingController.modalPresentationStyle = .fullScreen
                        presentingVC.present(hostingController, animated: true)
                    }
                }
                onCompletion?(success)
            }
        })
    }
}
