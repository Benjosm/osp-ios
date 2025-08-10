import AVFoundation
import CoreLocation
import Foundation

struct CapturedMediaItem {
    let imageData: Data
    let metadata: Metadata
}

class CameraControlHandler: NSObject {
    var photoOutput: AVCapturePhotoOutput?
    var cameraSetupManager: CameraSetupManager?
    var cameraUIManager: CameraUIManager?
    private let metadataCollector: MetadataCollector
    private let mediaStorageManager: MediaStorageManager

    /// Initializes the handler with required dependencies including metadata collector.
    init(metadataCollector: MetadataCollector) {
        self.metadataCollector = metadataCollector
        
        // Initialize media storage manager with file storage
        let fileStorage = FileSystemStorageManager()
        self.mediaStorageManager = MediaStorageManager(storageManager: fileStorage)
        
        super.init()
    }

    // Context to hold metadata during photo capture
    private class CaptureContext {
        let metadata: Metadata
        
        init(metadata: Metadata) {
            self.metadata = metadata
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        // Get current camera info from setup manager
        guard let setupManager = cameraSetupManager else { return }
        let isUsingBackCamera = setupManager.getIsUsingBackCamera()
        let currentFlashMode = setupManager.getFlashMode()
        
        // Create photo settings
        let settings = AVCapturePhotoSettings()
        
        // Set flash mode based on current camera and flash setting
        if isUsingBackCamera {
            settings.flashMode = currentFlashMode == .on ? .on : 
                               currentFlashMode == .auto ? .auto : .off
        } else {
            // No flash available for front camera in most devices
            settings.flashMode = .off
        }
        
        settings.isHighResolutionPhotoEnabled = true

        // Collect metadata at the precise moment of capture
        let metadata = metadataCollector.collect()

        // Create context to pass metadata
        let context = CaptureContext(metadata: metadata)
        let contextPointer = Unmanaged.passRetained(context).toOpaque()

        // Capture the photo with context
        photoOutput.capturePhoto(with: settings, delegate: self, context: contextPointer)
    }
    
    func switchCamera() {
        guard let setupManager = cameraSetupManager,
              let uiManager = cameraUIManager else { return }
              
        // Stop the current capture session
        setupManager.stopCaptureSession()
        
        // Switch camera
        let success = setupManager.switchCamera()
        
        if success {
            // Restart the capture session
            setupManager.startCaptureSession()
        } else {
            print("Failed to switch camera")
        }
    }
    
    func toggleFlashMode() {
        guard let setupManager = cameraSetupManager,
              let uiManager = cameraUIManager else { return }
              
        // Toggle flash mode
        let newFlashMode = setupManager.toggleFlashMode()
        
        // Update UI
        uiManager.updateFlashModeButton(flashMode: newFlashMode)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraControlHandler: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?, context: UnsafeMutableRawPointer?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            cleanupContext(context)
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Failed to convert photo to data")
            cleanupContext(context)
            return
        }
        
        // Retrieve metadata from context
        let metadata: Metadata
        if let ctx = context {
            let captureContext = Unmanaged<CaptureContext>.fromOpaque(ctx).takeRetainedValue()
            metadata = captureContext.metadata
        } else {
            // Fallback if context is missing
            metadata = Metadata(captureTime: ISO8601DateFormatter().string(from: Date()), location: nil, orientation: .unknown)
        }

        // Store media locally before enqueuing to upload queue
        mediaStorageManager.storeMedia(data: imageData, mediaType: .image, metadata: metadata) { [weak self] result in
            switch result {
            case .success(let url):
                print("Photo stored at \(url) and added to upload queue")
            case .failure(let error):
                print("Failed to store photo: \(error)")
            }
        }
    }
    
    // Helper to clean up context memory
    private func cleanupContext(_ context: UnsafeMutableRawPointer?) {
        guard let context = context else { return }
        _ = Unmanaged<CaptureContext>.fromOpaque(context).takeRetainedValue()
    }
}
