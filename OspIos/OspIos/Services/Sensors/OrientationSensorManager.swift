import UIKit

/// Singleton manager that provides access to the device's current orientation.
/// Begins generating orientation notifications when instantiated.
class OrientationSensorManager {
    /// Shared singleton instance
    static let shared = OrientationSensorManager()

    /// Private initializer starts orientation notifications
    private init() {
        // Enable device orientation monitoring
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    /// Returns the current physical orientation of the device.
    /// Values: .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight, .faceUp, .faceDown, .unknown
    var currentOrientation: UIDeviceOrientation {
        return UIDevice.current.orientation
    }
}
