import Foundation
import CoreLocation
import UIKit

// MARK: - Metadata Structure
struct Metadata {
    let captureTime: Date
    let latitude: Double?
    let longitude: Double?
    let orientation: Int // Using Int to match AVCapturePhoto.outputOrientation
}

// MARK: - MetadataCollector Class
class MetadataCollector: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    
    // Store latest valid location
    private var latestLatitude: Double?
    private var latestLongitude: Double?
    private var locationSemaphore: DispatchSemaphore?
    
    // Singleton instance
    static let shared = MetadataCollector()
    
    private override init() {
        locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Public Method to Collect Metadata
    // Orientation now passed in as an Int (AVCapturePhoto.outputOrientation)
    func collectMetadata(photoOrientation: Int) -> Metadata {
        // Capture time at the start for consistency
        let captureTime = Date()
    
        // Reset location values and semaphore
        latestLatitude = nil
        latestLongitude = nil
    
        let semaphore = DispatchSemaphore(value: 0)
        locationSemaphore = semaphore
    
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            if let location = locationManager.location {
                let coord = location.coordinate
                if isValidCoordinate(latitude: coord.latitude, longitude: coord.longitude) {
                    latestLatitude = coord.latitude
                    latestLongitude = coord.longitude
                }
            } else {
                // Request one-time location update
                locationManager.requestLocation()
                // Wait up to 2 seconds for the result
                let _ = semaphore.wait(timeout: .now() + 2.0)
            }
        }
    
        // Cleanup
        locationSemaphore = nil
    
        return Metadata(
            captureTime: captureTime,
            latitude: latestLatitude,
            longitude: latestLongitude,
            orientation: photoOrientation // Use passed-in orientation
        )
    }
    
    // MARK: - Upload-Ready Metadata Collection
    /// Collects metadata for a given media ID and returns it as a string dictionary suitable for upload
    func collectMetadata(forMediaId mediaId: String, orientation: Int) -> [String: String] {
        let metadata = collectMetadata(photoOrientation: orientation)
        
        var result: [String: String] = [:]
        result["mediaId"] = mediaId
        result["captureTime"] = "\(metadata.captureTime.timeIntervalSince1970)"
        result["orientation"] = "\(metadata.orientation)"
        if let lat = metadata.latitude {
            result["latitude"] = "\(lat)"
        }
        if let lon = metadata.longitude {
            result["longitude"] = "\(lon)"
        }
        
        return result
    }

    // MARK: - Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let coord = location.coordinate
            if isValidCoordinate(latitude: coord.latitude, longitude: coord.longitude) {
                latestLatitude = coord.latitude
                latestLongitude = coord.longitude
            } else {
                print("Warning: Received invalid location coordinates (lat: \(coord.latitude), lng: \(coord.longitude)) and will discard them.")
            }
        }
        // Always signal the semaphore to unblock collectMetadata()
        locationSemaphore?.signal()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error)")
        // Signal the semaphore even on failure to prevent blocking
        locationSemaphore?.signal()
    }

    // MARK: - Coordinate Validation
    private func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
