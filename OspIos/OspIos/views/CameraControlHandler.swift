import AVFoundation
import CoreLocation
// Ensure Metadata is available
import Foundation

struct CapturedMediaItem {
    let imageData: Data
    let metadata: Metadata
}

class CameraControlHandler: NSObject {
    var photoOutput: AVCapturePhotoOutput?
    var cameraSetupManager: CameraSetupManager?
    var cameraUIManager: CameraUIManager?

    // Remove locationManager, as metadata now includes location via MetadataCollector
    
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
        let metadata = MetadataCollector.shared.collectMetadata()

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
            metadata = Metadata(captureTime: Date(), latitude: nil, longitude: nil, orientation: .unknown)
        }

        // Create captured media item
        let capturedItem = CapturedMediaItem(
            imageData: imageData,
            metadata: metadata
        )
        
        // Add captured item to upload queue with metadata
        let enqueued = UploadQueueTask.shared.enqueue(media: imageData, metadata: metadata)

        if enqueued {
            print("Photo captured and added to upload queue - Timestamp: \(metadata.captureTime), Location: \(metadata.latitude),\(metadata.longitude)")
        } else {
            print("Photo captured but not added to upload queue (possible duplicate)")
        }
    }
    
    // Helper to clean up context memory
    private func cleanupContext(_ context: UnsafeMutableRawPointer?) {
        guard let context = context else { return }
        _ = Unmanaged<CaptureContext>.fromOpaque(context).takeRetainedValue()
    }
}
