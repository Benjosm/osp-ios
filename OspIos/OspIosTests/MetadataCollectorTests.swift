import XCTest
@testable import OspIos

class MetadataCollectorTests: XCTestCase {
    var metadataCollector: MetadataCollector!
    var mockCLLocationManager: MockCLLocationManager!
    var mockOrientationManager: OrientationSensorManager!

    override func setUp() {
        super.setUp()
        mockCLLocationManager = MockCLLocationManager()
        mockOrientationManager = MockOrientationSensorManager()
        metadataCollector = MetadataCollector(
            locationManager: mockCLLocationManager,
            orientationSensorManager: mockOrientationManager
        )
    }

    override func tearDown() {
        metadataCollector = nil
        mockCLLocationManager = nil
        mockOrientationManager = nil
        super.tearDown()
    }

    // MARK: - Unit Tests

    func testCollect_WithValidLocation_ReturnsMetadataWithCoordinates() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let validCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: validCoordinate, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 10, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata.location?.latitude, validCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(metadata.location?.longitude, validCoordinate.longitude, accuracy: 0.001)
        XCTAssertEqual(metadata.captureTime, "2021-06-30T16:00:00Z")
    }

    func testCollect_WithBoundaryLatitude_Min_ReturnsValidLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let coordinate = CLLocationCoordinate2D(latitude: -90.0, longitude: 0.0)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 10, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata.location)
        XCTAssertEqual(metadata.location?.latitude, -90.0, accuracy: 0.001)
        XCTAssertEqual(metadata.location?.longitude, 0.0, accuracy: 0.001)
    }

    func testCollect_WithBoundaryLatitude_Max_ReturnsValidLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let coordinate = CLLocationCoordinate2D(latitude: 90.0, longitude: 0.0)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 10, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata.location)
        XCTAssertEqual(metadata.location?.latitude, 90.0, accuracy: 0.001)
        XCTAssertEqual(metadata.location?.longitude, 0.0, accuracy: 0.001)
    }

    func testCollect_WithBoundaryLongitude_Min_ReturnsValidLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let coordinate = CLLocationCoordinate2D(latitude: 0.0, longitude: -180.0)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 10, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata.location)
        XCTAssertEqual(metadata.location?.latitude, 0.0, accuracy: 0.001)
        XCTAssertEqual(metadata.location?.longitude, -180.0, accuracy: 0.001)
    }

    func testCollect_WithBoundaryLongitude_Max_ReturnsValidLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let coordinate = CLLocationCoordinate2D(latitude: 0.0, longitude: 180.0)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 10, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata.location)
        XCTAssertEqual(metadata.location?.latitude, 0.0, accuracy: 0.001)
        XCTAssertEqual(metadata.location?.longitude, 180.0, accuracy: 0.001)
    }

    func testCollect_WithInvalidLocation_ReturnsNilLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let invalidCoordinate = CLLocationCoordinate2D(latitude: 100.0, longitude: 200.0)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: invalidCoordinate, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata.location)
    }

    func testCollect_WithNoLocation_ReturnsNilLocation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        mockCLLocationManager.mockedLocation = nil

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata.location)
    }

    func testCollect_ContainsValidCaptureTime() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let validCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: validCoordinate, timestamp: fixedDate)

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata.captureTime, "2021-06-30T16:00:00Z")
    }

    func testCollect_WithValidOrientation_ReturnsMetadataWithOrientation() {
        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let expectedOrientation: Double = 90.0
        (mockOrientationManager as! MockOrientationSensorManager).mockedOrientation = expectedOrientation

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)

        // Assert
        XCTAssertEqual(metadata.orientation, expectedOrientation)
    }

    // MARK: - Integration Test

    func testIntegration_CapturePhoto_EnqueuesMetadata() {
        // This test assumes UploadQueueTask can be observed
        // In practice, we might need a completion handler or delegate

        // Arrange
        let fixedDate = Date(timeIntervalSince1970: 1625097600)
        let validCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockedLocation = CLLocation(coordinate: validCoordinate, timestamp: fixedDate)

        let mockOrientationManager = MockOrientationSensorManager()
        mockOrientationManager.mockedOrientation = 90.0
        let metadataCollector = MetadataCollector(
            locationManager: mockCLLocationManager,
            orientationSensorManager: mockOrientationManager
        )

        let photoData = Data([0xFF, 0xD8, 0xFF]) // Minimal JPEG
        let uploadQueue = UploadQueueTask.shared

        let existingCount = uploadQueue.getTasks().count

        // Act
        let metadata = metadataCollector.collect(now: fixedDate)
        let mediaItem = MediaItem(data: photoData, metadata: metadata, type: .photo)
        uploadQueue.enqueue(media: photoData, metadata: metadata)

        // Assert
        let newCount = uploadQueue.getTasks().count
        XCTAssertEqual(newCount, existingCount + 1)

        let lastTask = uploadQueue.getTasks().last
        XCTAssertNotNil(lastTask)
        XCTAssertEqual(lastTask?.metadata.captureTime, "2021-06-30T16:00:00Z")
        XCTAssertEqual(lastTask?.metadata.location?.latitude, validCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(lastTask?.metadata.location?.longitude, validCoordinate.longitude, accuracy: 0.001)
XCTAssertEqual(lastTask?.metadata.orientation, 90.0)
    }
}

// MARK: - Mocks

extension MetadataCollectorTests {
    class MockCLLocationManager: CLLocationManager {
        var mockedLocation: CLLocation?
        override var location: CLLocation? {
            return mockedLocation
        }
    }

    class MockOrientationSensorManager: OrientationSensorManager {
        var mockedOrientation: Double = 0.0
        override var currentOrientation: Double {
            return mockedOrientation
        }
    }
}
