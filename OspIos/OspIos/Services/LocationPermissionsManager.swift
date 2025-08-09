import Foundation
import CoreLocation

class LocationPermissionsManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionsManager()
    
    private let locationManager = CLLocationManager()
    
    private override init() {
        super.init()
        locationManager.delegate = self
    }
    
    // Check if location permissions are granted
    func hasPermissions() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    // Request location permissions
    func requestPermissions(from viewController: UIViewController) {
        // The actual request will be made, and the user will be prompted
        // The plist file must have NSLocationWhenInUseUsageDescription key
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Show an alert to direct user to settings if permissions are denied
    func showErrorAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Location Access Required",
            message: "Location access is required to capture photos with metadata. Please enable location permissions in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Handle authorization changes if needed
    }
    
    // Retrieve the most recently known location
    func getCurrentLocation() -> CLLocation? {
        return hasPermissions() ? locationManager.location : nil
    }
}
