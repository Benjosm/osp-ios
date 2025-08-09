import AVFoundation
import CoreLocation

enum FlashMode {
    case off, on, auto
}

// Struct to hold captured media and associated metadata
struct CapturedMediaItem {
    let imageData: Data
    let timestamp: Date
    let location: CLLocation?
}

class CameraControlHandler: NSObject {
    var photoOutput: AVCapturePhotoOutput?
    var cameraSetupManager: CameraSetupManager?
    var cameraUIManager: CameraUIManager?
    var locationManager = LocationPermissionsManager.shared
    
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

        // Capture the photo
        photoOutput.capturePhoto(with: settings, delegate: self)
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
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Failed to convert photo to data")
            return
        }
        
        // Collect metadata
        let timestamp = photo.captureDate ?? Date()
        let location = locationManager.getCurrentLocation()
        
        // Create captured media item
        let capturedItem = CapturedMediaItem(
            imageData: imageData,
            timestamp: timestamp,
            location: location
        )
        
        // Create metadata dictionary for upload
        var metadata: [String: Any] = [
            "timestamp": timestamp.timeIntervalSince1970,
            "camera_position": isUsingBackCamera ? "back" : "front",
            "flash_mode": currentFlashMode == .on ? "on" : currentFlashMode == .auto ? "auto" : "off"
        ]

        // Add location metadata if available
        if let location = location {
            metadata["location"] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "timestamp": location.timestamp.timeIntervalSince1970
            ]
        }

        // Add captured item to upload queue
        let enqueued = UploadQueueTask.shared.enqueue(media: imageData, metadata: metadata)

        if enqueued {
            print("Photo captured and added to upload queue - Timestamp: \(timestamp), Location: \(location?.coordinate.latitude),\(location?.coordinate.longitude)")
        } else {
            print("Photo captured but not added to upload queue (possible duplicate)")
        }
    }
}
