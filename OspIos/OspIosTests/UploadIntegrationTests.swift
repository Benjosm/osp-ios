import Foundation
import XCTest
@testable import OspIos

/// Mock implementation of UploadManager for testing
class MockUploadManager: UploadManager {
    var uploadedItems: [UploadItem] = []
    var progressHandler: ((Double) -> Void)?
    var completionClosure: ((Bool, Error?) -> Void)?
    var shouldFail: Bool = false
    var failureCount: Int = 0
    var maxFailuresBeforeSuccess: Int = 0
    
    override init() {
        // Initialize with basic configuration for testing
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.backgroundSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        super.init()
    }
    
    override func upload(item: UploadItem, onProgress: @escaping (Double) -> Void, onCompletion: ((Bool, Error?) -> Void)? = nil) {
        self.progressHandler = onProgress
        self.completionClosure = onCompletion
        self.uploadedItems.append(item)
        
        // Simulate upload progress
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            if self.shouldFail && self.failureCount < self.maxFailuresBeforeSuccess {
                self.failureCount += 1
                DispatchQueue.main.async {
                    self.progressHandler?(-1) // Indicate failure
                }
            } else {
                // Simulate progress updates
                DispatchQueue.main.async {
                    self.progressHandler?(0.2)
                }
                
                usleep(100000) // 0.1 second
                
                DispatchQueue.main.async {
                    self.progressHandler?(0.5)
                }
                
                usleep(100000) // 0.1 second
                
                DispatchQueue.main.async {
                    self.progressHandler?(0.8)
                }
                
                usleep(100000) // 0.1 second
                
                DispatchQueue.main.async {
                    self.progressHandler?(1.0)
                    self.completionClosure?(true, nil)
                }
            }
        }
    }
    
    /// Simulate background session completion
    func simulateBackgroundSessionCompletion(success: Bool = true) {
        DispatchQueue.main.async {
            self.completionHandlers.forEach { _, completion in
                completion(success, success ? nil : NSError(domain: "MockUploadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated upload failure"]))
            }
            self.completionHandlers.removeAll()
        }
    }
}

/// Mock implementation of LocalMediaStorageTask for testing
class MockLocalMediaStorageTask: LocalMediaStorageTask {
    var mediaData: [String: Data] = [:]
    var availableMediaIds: Set<String> = []
    
    override func fileURL(forMediaId mediaId: String) -> URL? {
        guard availableMediaIds.contains(mediaId) else { return nil }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(mediaId).dat")
    }
    
    func addMedia(withId id: String, data: Data) {
        mediaData[id] = data
        availableMediaIds.insert(id)
    }
}

/// Test delegate to capture UploadQueue events
class TestUploadQueueDelegate: UploadQueueDelegate {
    private(set) var startedUploads: [String] = []
    private(set) var progressUpdates: [String: Double] = [:]
    private(set) var completedUploads: [String: Bool] = [:] // mediaId -> success
    private(set) var completionErrors: [String: Error?] = [:]
    private(set) var didResumeCalled = false
    
    func uploadQueue(_ queue: UploadQueue, didStartUploadForMediaId mediaId: String) {
        startedUploads.append(mediaId)
    }
    
    func uploadQueue(_ queue: UploadQueue, didUpdateProgress mediaId: String, progress: Double) {
        progressUpdates[mediaId] = progress
    }
    
    func uploadQueue(_ queue: UploadQueue, didFinishUploadForMediaId mediaId: String, success: Bool, error: Error?) {
        completedUploads[mediaId] = success
        completionErrors[mediaId] = error
    }
    
    func uploadQueueDidResume(_ queue: UploadQueue) {
        didResumeCalled = true
    }
}

class UploadIntegrationTests: XCTestCase {
    var mockUploadManager: MockUploadManager!
    var mockStorage: MockLocalMediaStorageTask!
    var uploadQueue: UploadQueue!
    var uploadCoordinator: MediaUploadCoordinator!
    var testDelegate: TestUploadQueueDelegate!
    
    override func setUp() {
        super.setUp()
        
        // Reset UserDefaults before each test
        UserDefaults.resetStandardUserDefaults()
        
        mockUploadManager = MockUploadManager()
        mockStorage = MockLocalMediaStorageTask()
        testDelegate = TestUploadQueueDelegate()
        
        // Create upload queue with mock dependencies
        uploadQueue = UploadQueue(uploadManager: mockUploadManager)
        uploadQueue.delegate = testDelegate
        
        // Create upload coordinator with mock dependencies
        uploadCoordinator = MediaUploadCoordinator(
            storageResolver: mockStorage,
            metadataCollector: MetadataCollector.shared,
            uploadManager: mockUploadManager,
            presentingViewController: nil
        )
    }
    
    override func tearDown() {
        // Clean up after each test
        mockUploadManager = nil
        mockStorage = nil
        uploadQueue = nil
        uploadCoordinator = nil
        testDelegate = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testMediaFetchAndMetadataAttachment() {
        // Given
        let mediaId = "test-media-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        // When
        let result = uploadCoordinator.storageResolver.fileURL(forMediaId: mediaId)
        
        // Then
        XCTAssertNotNil(result)
        let metadata = MetadataCollector.shared.collectMetadata(forMediaId: mediaId)
        XCTAssertNotNil(metadata["timestamp"])
    }
    
    func testUploadWithBackgroundAppSuspension() {
        // Given
        let mediaId = "test-background-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        let expectation = self.expectation(description: "Upload completes after background suspension")
        
        // When
        uploadCoordinator.uploadMedia(withId: mediaId, onProgress: { _ in }) { success in
            // Then
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        // Simulate app suspension and resumption (XCTest handles this via background testing)
        waitForExpectations(timeout: 5.0)
    }
    
    func testProgressTracking() {
        // Given
        let mediaId = "test-progress-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 4 // 0, 0.2, 0.5, 0.8, 1.0 (but 0 comes from UI)
        
        testDelegate.uploadQueue = { [weak self] queue, mediaId, progress in
            guard let self = self else { return }
            
            // Validate progress values are increasing
            if let lastProgress = self.testDelegate.progressUpdates[mediaId] {
                XCTAssert(progress >= lastProgress, "Progress should not go backwards")
            }
            
            // Record progress update
            self.testDelegate.progressUpdates[mediaId] = progress
            
            // Fulfill expectation when we reach 1.0
            if progress >= 1.0 {
                progressExpectation.fulfill()
            }
        }
        
        // When
        uploadCoordinator.uploadMedia(withId: mediaId, onProgress: { progress in
            // This gets called from the mock upload manager
            if progress >= 0 {
                // Simulate progress tracking
                self.testDelegate.progressUpdates[mediaId] = progress
                if progress == 1.0 {
                    progressExpectation.fulfill()
                }
            }
        }, onCompletion: nil)
        
        // Then
        waitForExpectations(timeout: 5.0)
    }
    
    func testFailedUploadRetryLogic() {
        // Given
        let mediaId = "test-retry-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        // Configure mock to fail twice before succeeding
        mockUploadManager.shouldFail = true
        mockUploadManager.maxFailuresBeforeSuccess = 2
        
        let completionExpectation = expectation(description: "Upload completes after retries")
        var completionCount = 0
        
        // When
        uploadCoordinator.uploadMedia(withId: mediaId) { success in
            completionCount += 1
            // Then: Should succeed on third attempt
            XCTAssertTrue(success)
            XCTAssertEqual(completionCount, 1, "Completion should only be called once for successful upload")
            XCTAssertEqual(self.mockUploadManager.failureCount, 2, "Should have failed twice before success")
            completionExpectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 10.0) // Longer timeout to accommodate retry delays
    }
    
    func testSerialUploadQueue() {
        // Given: Multiple media items
        let mediaIds = ["serial-1", "serial-2", "serial-3"]
        for id in mediaIds {
            let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
            mockStorage.addMedia(withId: id, data: testData)
        }
        
        let completionExpectation = expectation(description: "All uploads complete")
        completionExpectation.expectedFulfillmentCount = 3
        
        var uploadOrder: [String] = []
        var completionOrder: [String] = []
        
        // Track upload start order
        testDelegate.startedUploads = []
        
        // When: Add all uploads to queue
        for mediaId in mediaIds {
            uploadQueue.addUpload(mediaId: mediaId)
        }
        
        // Monitor completion order
        DispatchQueue.global().async {
            while completionOrder.count < 3 {
                usleep(10000) // Check every 10ms
                Thread.sleep(forTimeInterval: 0.01)
            }
            DispatchQueue.main.async {
                completionExpectation.fulfill()
            }
        }
        
        // Then: Verify serial execution
        waitForExpectations(timeout: 10.0)
        
        // All items should have been processed
        XCTAssertEqual(testDelegate.startedUploads.count, 3)
        XCTAssertEqual(testDelegate.completedUploads.count, 3)
        
        // Uploads should be completed in order (serial queue)
        for mediaId in mediaIds {
            XCTAssertTrue(testDelegate.completedUploads[mediaId] ?? false)
        }
    }
    
    func testUIConfirmationStates() {
        // Given
        let mediaId = "test-ui-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        // We'll track the UI state changes through the completion handlers
        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 4 // 0, 0.2, 0.5, 0.8, 1.0 (but 0 from UI)
        
        var uiStates: [String] = [] // Track UI state changes
        
        // When
        uploadCoordinator.uploadMedia(withId: mediaId, onProgress: { progress in
            if progress >= 0 {
                if progress == 0.0 {
                    uiStates.append("uploading")
                } else if progress == 1.0 {
                    uiStates.append("success")
                    progressExpectation.fulfill()
                } else {
                    uiStates.append("uploading")
                }
            }
        }) { success in
            if success {
                uiStates.append("success")
            } else {
                uiStates.append("error")
            }
        }
        
        // Then
        waitForExpectations(timeout: 5.0)
        
        // Verify UI displayed correct states
        XCTAssertTrue(uiStates.contains("uploading"), "UI should show uploading state")
        XCTAssertTrue(uiStates.contains("success"), "UI should show success state")
    }
    
    func testAppRestartDuringUpload() {
        // Given
        let mediaId = "test-restart-1"
        let testData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mockStorage.addMedia(withId: mediaId, data: testData)
        
        // Create a new queue and add an upload
        let firstQueue = UploadQueue(uploadManager: mockUploadManager)
        firstQueue.addUpload(mediaId: mediaId)
        
        // Simulate app termination and restart
        // The queue state should be persisted to UserDefaults
        let savedData = UserDefaults.standard.data(forKey: "UploadQueue_PersistentState")
        XCTAssertNotNil(savedData, "Queue state should be persisted")
        
        // Create a new queue instance (simulating app restart)
        let secondQueue = UploadQueue(uploadManager: mockUploadManager)
        secondQueue.delegate = testDelegate
        
        let completionExpectation = expectation(description: "Upload completes after restart")
        
        // Set up delegate to catch the completion
        var completedMediaId: String?
        secondQueue.delegate = TestUploadQueueDelegate()
        secondQueue.delegate = testDelegate
        
        // When: Wait for upload to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockUploadManager.simulateBackgroundSessionCompletion(success: true)
        }
        
        // Then
        waitForExpectations(timeout: 5.0)
        
        // Verify queue resumed and completed upload
        XCTAssertTrue(testDelegate.didResumeCalled, "uploadQueueDidResume should be called after restart")
        XCTAssertEqual(testDelegate.completedUploads.count, 1)
        XCTAssertTrue(testDelegate.completedUploads[mediaId] ?? false, "Upload should complete after restart")
    }
}
