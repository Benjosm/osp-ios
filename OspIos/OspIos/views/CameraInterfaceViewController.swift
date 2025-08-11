import UIKit
import CoreLocation
import Foundation

class CameraInterfaceViewController: UIViewController {
    private let cameraSetupManager = CameraSetupManager()
    private let cameraUIManager = CameraUIManager()
    private let metadataCollector: MetadataCollector
    private let cameraControlHandler: CameraControlHandler
    private let uploadConfirmationPresenter: UploadConfirmationPresenter
    
    required init?(coder: NSCoder) {
        let locationManager = LocationPermissionsManager.shared.locationManager
        let orientationManager = OrientationSensorManager.shared
        self.metadataCollector = MetadataCollector(locationManager: locationManager, orientationSensorManager: orientationManager)
        self.cameraControlHandler = CameraControlHandler(metadataCollector: self.metadataCollector)
        self.uploadConfirmationPresenter = UploadConfirmationPresenter(presentingViewController: self)
        super.init(coder: coder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let locationManager = LocationPermissionsManager.shared.locationManager
        let orientationManager = OrientationSensorManager.shared
        self.metadataCollector = MetadataCollector(locationManager: locationManager, orientationSensorManager: orientationManager)
        self.cameraControlHandler = CameraControlHandler(metadataCollector: self.metadataCollector)
        self.uploadConfirmationPresenter = UploadConfirmationPresenter(presentingViewController: self)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Connect the control handler to the managers
        cameraControlHandler.cameraSetupManager = cameraSetupManager
        cameraControlHandler.cameraUIManager = cameraUIManager
        cameraControlHandler.photoOutput = cameraSetupManager.photoOutput
        
        // Set up the camera components
        cameraSetupManager.setupCaptureSession()
        cameraSetupManager.setupPhotoOutput()
        cameraSetupManager.setupPreviewLayer(in: view)
        cameraUIManager.setupCameraInterface(in: view)
        cameraUIManager.setupShutterButton(in: view, target: self, action: #selector(shutterButtonTapped))
        cameraUIManager.setupCameraSwitchButton(target: self, action: #selector(cameraSwitchButtonTapped))
        cameraUIManager.setupFlashModeButton(target: self, action: #selector(flashModeButtonTapped))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraSetupManager.startCaptureSession()
        metadataCollector.startCollection()  // Initialize metadata collection
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraSetupManager.stopCaptureSession()
    }

    @objc func shutterButtonTapped() {
        let metadata = metadataCollector.captureOccurred()
        cameraControlHandler.capturePhoto(withMetadata: metadata) { [weak self] success, mediaId in
            guard success, let mediaId = mediaId, let self = self else {
                print("Photo capture failed")
                return
            }
            
            // Create upload coordinator with presenting view controller
            let uploadCoordinator = MediaUploadCoordinator(
                presentingViewController: self
            )
            
            // Start uploading the captured media
            uploadCoordinator.uploadMedia(withId: mediaId) { progress in
                // Handle upload progress if needed
                if progress == 1.0 {
                    print("Upload completed successfully")
                }
            } onCompletion: { [weak self] success, trustScore, uploadTime in
                guard let self = self else { return }
                if success {
                    self.uploadConfirmationPresenter.showSuccess(trustScore: trustScore, uploadTime: uploadTime)
                } else {
                    self.uploadConfirmationPresenter.showError()
                }
            }
        }
    }
    
    @objc func cameraSwitchButtonTapped() {
        cameraControlHandler.switchCamera()
    }
    
    @objc func flashModeButtonTapped() {
        cameraControlHandler.toggleFlashMode()
    }
}
