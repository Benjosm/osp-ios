import Foundation
import CoreLocation
import UIKit

/// Struct representing the metadata collected at the time of media capture.
struct Metadata {
    /// ISO 8601 formatted timestamp of capture
    let captureTime: String
    /// Optional geographic coordinate (latitude, longitude)
    let location: CLLocationCoordinate2D?
    /// Device orientation at time of capture
    let orientation: UIDeviceOrientation
}

/// Responsible for collecting synchronized metadata at the time of media capture.
class MetadataCollector {
    private weak var locationManager: CLLocationManager?
    private let orientationSensorManager: OrientationSensorManager

    /// Initializes the collector with required managers.
    /// - Parameters:
    ///   - locationManager: Provides access to current location via CoreLocation.
    ///   - orientationSensorManager: Provides current device orientation.
    init(locationManager: CLLocationManager, orientationSensorManager: OrientationSensorManager) {
        self.locationManager = locationManager
        self.orientationSensorManager = orientationSensorManager
    }

    /// Collects the current metadata (time, location, orientation) as close together as possible.
    /// Validates latitude and longitude ranges. If invalid, location is set to nil.
    /// - Returns: Metadata object with capture time, validated location, and current orientation.
    func collect(now: Date = Date()) -> Metadata {
        // Capture all values as close in time as possible
        let captureTime = ISO8601DateFormatter().string(from: now)
        var coordinate: CLLocationCoordinate2D?

        if let location = locationManager?.location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude

            // Validate coordinate ranges
            if (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lon) {
                coordinate = location.coordinate
            } else {
                print("Warning: Invalid location coordinate detected (lat: \(lat), lon: \(lon)), setting location to nil.")
            }
        }

        let orientation = orientationSensorManager.currentOrientation

        return Metadata(
            captureTime: captureTime,
            location: coordinate,
            orientation: orientation
        )
    }
}
