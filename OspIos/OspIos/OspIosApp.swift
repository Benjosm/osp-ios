//
//  OspIosApp.swift
//  OspIos
//

import SwiftUI

@main
struct OspIosApp: App {
    // Use AppStorage to persist the onboarding status
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            // Conditionally display the main screen or the sign-in process
            if hasCompletedOnboarding {
                ContentView() // Show main app content after onboarding
            } else {
                SignInView() // Show Apple Sign-in flow initially
            }
        }
    }
}
