import AVFoundation

enum FlashMode {
    case off, on, auto
}

class CameraSetupManager: NSObject {
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var backCameraInput: AVCaptureDeviceInput?
    var frontCameraInput: AVCaptureDeviceInput?
    var currentInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var isUsingBackCamera = true
    private var currentFlashMode: FlashMode = .off
    
    func setupCaptureSession() {
        captureSession.sessionPreset = .high

        // Find back and front cameras
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        backCamera = deviceDiscoverySession.devices.first

        let frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        frontCamera = frontCameraDiscoverySession.devices.first

        // Add back camera input as default
        if let backCamera = backCamera {
            do {
                backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if captureSession.canAddInput(backCameraInput!) {
                    captureSession.addInput(backCameraInput!)
                    currentInput = backCameraInput
                }
            } catch {
                print("Error creating back camera input: \(error)")
            }
        }
    }

    func setupPhotoOutput() {
        photoOutput = AVCapturePhotoOutput()
        photoOutput?.isHighResolutionCaptureEnabled = true
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    func setupPreviewLayer(in view: UIView) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        if let previewLayer = previewLayer {
            view.layer.insertSublayer(previewLayer, at: 0)
            previewLayer.frame = view.frame
        }
    }

    func startCaptureSession() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    func stopCaptureSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // Toggle between front and back cameras
    func switchCamera() -> Bool {
        // Store the current camera being used
        let newCameraPosition: AVCaptureDevice.Position = isUsingBackCamera ? .front : .back
        
        // Find the new camera device
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: newCameraPosition
        )
        
        guard let newCamera = discoverySession.devices.first else {
            print("Could not find camera with position: \(newCameraPosition)")
            return false
        }
        
        // Create new input
        var newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: newCamera)
        } catch {
            print("Error creating device input: \(error)")
            return false
        }
        
        // See if the session can add the new input
        if !captureSession.canAddInput(newInput) {
            print("Cannot add input to session")
            return false
        }
        
        // Remove old input and add new input
        captureSession.beginConfiguration()
        if let currentInput = currentInput {
            captureSession.removeInput(currentInput)
        }
        
        captureSession.addInput(newInput)
        captureSession.commitConfiguration()
        
        // Update references
        currentInput = newInput
        isUsingBackCamera = !isUsingBackCamera
        
        // Apply flash mode if switching to back camera
        if isUsingBackCamera, let device = backCamera, device.hasFlash {
            do {
                try device.lockForConfiguration()
                switch currentFlashMode {
                case .off:
                    device.flashMode = .off
                case .on:
                    device.flashMode = .on
                case .auto:
                    device.flashMode = .auto
                }
                device.unlockForConfiguration()
            } catch {
                print("Error setting flash mode: \(error)")
            }
        }
        
        return true
    }
    
    // Toggle flash mode (off -> on -> auto -> off)
    func toggleFlashMode() -> FlashMode {
        // Only allow flash on back camera
        guard isUsingBackCamera, let device = backCamera, device.hasFlash else {
            return .off
        }
        
        // Cycle through the flash modes
        switch currentFlashMode {
        case .off:
            currentFlashMode = .on
        case .on:
            currentFlashMode = .auto
        case .auto:
            currentFlashMode = .off
        }
        
        // Apply the new flash mode
        do {
            try device.lockForConfiguration()
            switch currentFlashMode {
            case .off:
                device.flashMode = .off
            case .on:
                device.flashMode = .on
            case .auto:
                device.flashMode = .auto
            }
            device.unlockForConfiguration()
        } catch {
            print("Error setting flash mode: \(error)")
        }
        
        return currentFlashMode
    }
    
    // Get current flash mode
    func getFlashMode() -> FlashMode {
        return currentFlashMode
    }
    
    // Check if using back camera
    func getIsUsingBackCamera() -> Bool {
        return isUsingBackCamera
    }
}
