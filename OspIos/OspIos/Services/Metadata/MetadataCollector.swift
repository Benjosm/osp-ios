import Foundation
import CoreLocation
import UIKit

/// Struct representing the metadata collected at the time of media capture.
struct CaptureMetadata {
    /// Timestamp of capture
    let captureTime: Date
    /// Optional geographic coordinate - latitude
    let latitude: Double?
    /// Optional geographic coordinate - longitude
    let longitude: Double?
    /// Device orientation at time of capture
    let orientation: UIDeviceOrientation
}

/// Responsible for collecting synchronized metadata at the time of media capture.
class MetadataCollector: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager
    private let orientationSensorManager: OrientationSensorManager
    private var frozenMetadata: CaptureMetadata?

    /// Initializes the collector with required managers.
    /// - Parameters:
    ///   - locationManager: Provides access to current location via CoreLocation.
    ///   - orientationSensorManager: Provides current device orientation.
    init(locationManager: CLLocationManager, orientationSensorManager: OrientationSensorManager) {
        self.locationManager = locationManager
        self.orientationSensorManager = orientationSensorManager
        super.init()
    }

    /// Prepares the metadata collector for capture by setting up location manager.
    func startCollection() {
        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()  // Start location updates immediately
        
        // Request location authorization if needed
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Captures the current metadata (time, location, orientation) at the exact moment of media capture.
    /// Validates coordinates and freezes the data for subsequent access.
    /// - Returns: Frozen CaptureMetadata object valid for the duration of this capture session.
    func captureOccurred() -> CaptureMetadata {
        // Capture all values simultaneously
        let captureTime = Date()
        var latitude: Double?
        var longitude: Double?

        if let location = locationManager.location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude

            // Validate coordinate ranges
            if (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lon) {
                latitude = lat
                longitude = lon
            } else {
                print("Warning: Invalid location coordinate detected (lat: \(lat), lon: \(lon)), setting location to nil.")
            }
        }

        // Get current orientation from shared sensor manager
        let orientation = orientationSensorManager.currentOrientation

        // Freeze metadata for this capture session
        frozenMetadata = CaptureMetadata(
            captureTime: captureTime,
            latitude: latitude,
            longitude: longitude,
            orientation: orientation
        )

        return frozenMetadata!
    }

    /// Provides access to current or frozen capture metadata.
    /// - Returns: Most recent metadata (frozen if capture occurred, current otherwise)
    func collect() -> CaptureMetadata {
        // Return frozen metadata if capture already occurred
        if let frozen = frozenMetadata {
            return frozen
        }

        // Fall back to current values for pre-capture scenarios
        let captureTime = Date()
        var latitude: Double?
        var longitude: Double?

        if let location = locationManager.location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude

            // Validate coordinate ranges
            if (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lon) {
                latitude = lat
                longitude = lon
            }
        }

        return CaptureMetadata(
            captureTime: captureTime,
            latitude: latitude,
            longitude: longitude,
            orientation: orientationSensorManager.currentOrientation
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}
