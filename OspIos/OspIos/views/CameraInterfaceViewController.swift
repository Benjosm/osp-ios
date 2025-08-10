import UIKit
import CoreLocation
import Foundation

class CameraInterfaceViewController: UIViewController {
    private let cameraSetupManager = CameraSetupManager()
    private let cameraUIManager = CameraUIManager()
    private let cameraControlHandler: CameraControlHandler

    required init?(coder: NSCoder) {
        let locationManager = LocationPermissionsManager.shared.locationManager
        let orientationManager = OrientationSensorManager.shared
        let metadataCollector = MetadataCollector(locationManager: locationManager, orientationSensorManager: orientationManager)
        self.cameraControlHandler = CameraControlHandler(metadataCollector: metadataCollector)
        super.init(coder: coder)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let locationManager = LocationPermissionsManager.shared.locationManager
        let orientationManager = OrientationSensorManager.shared
        let metadataCollector = MetadataCollector(locationManager: locationManager, orientationSensorManager: orientationManager)
        self.cameraControlHandler = CameraControlHandler(metadataCollector: metadataCollector)
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraSetupManager.stopCaptureSession()
    }

    @objc func shutterButtonTapped() {
        cameraControlHandler.capturePhoto()
    }
    
    @objc func cameraSwitchButtonTapped() {
        cameraControlHandler.switchCamera()
    }
    
    @objc func flashModeButtonTapped() {
        cameraControlHandler.toggleFlashMode()
    }
}
