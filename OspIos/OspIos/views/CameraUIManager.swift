import UIKit

class CameraUIManager: NSObject {
    private let shutterButton = UIButton()
    private let cameraSwitchButton = UIButton()
    private let flashModeButton = UIButton()

    func setupCameraInterface(in view: UIView) {
        view.backgroundColor = .black
        
        // Set up the camera switch button (swap between front and back)
        cameraSwitchButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        cameraSwitchButton.tintColor = .white
        cameraSwitchButton.frame = CGRect(x: view.bounds.maxX - 60, y: 60, width: 44, height: 44)
        view.addSubview(cameraSwitchButton)
        
        // Set up the flash mode button
        updateFlashModeButton(flashMode: .off) // Default to off
        flashModeButton.frame = CGRect(x: view.bounds.maxX - 60, y: 120, width: 44, height: 44)
        view.addSubview(flashModeButton)
    }

    func setupShutterButton(in view: UIView, target: Any?, action: Selector) {
        shutterButton.setBackgroundImage(UIImage(systemName: "circle.fill"), for: .normal)
        shutterButton.tintColor = .white
        shutterButton.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        shutterButton.center = CGPoint(x: view.center.x, y: view.bounds.maxY - 60)
        shutterButton.addTarget(target, action: action, for: .touchUpInside)
        view.addSubview(shutterButton)
    }
    
    func setupCameraSwitchButton(target: Any?, action: Selector) {
        cameraSwitchButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    func setupFlashModeButton(target: Any?, action: Selector) {
        flashModeButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    func updateFlashModeButton(flashMode: FlashMode) {
        var imageName: String
        switch flashMode {
        case .off:
            imageName = "bolt.slash.fill"
        case .on:
            imageName = "bolt.fill"
        case .auto:
            imageName = "bolt.badge.a.fill"
        }
        
        flashModeButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
}
