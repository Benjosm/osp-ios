import Foundation

struct Config {
    static var backendURL: String {
        #if DEBUG
        return "https://dev.osp-backend.example"
        #elseif STAGING
        return "https://staging.osp-backend.example"
        #else
        return "https://prod.osp-backend.example"
        #endif
    }
}

// MARK: - Build Configuration Setup
/*
 Add to your .xcconfig files:
 
 Debug.xcconfig:
 SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG
 
 Release.xcconfig:
 SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) PRODUCTION
 
 Staging.xcconfig (if applicable):
 SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STAGING
*/
