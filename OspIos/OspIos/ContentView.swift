import SwiftUI
import AuthenticationServices
import UIKit

struct ContentView: View {
    @State private var showAppleSignIn = false
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            checkAndPresentAppleSignIn()
        }
        .sheet(isPresented: $showAppleSignIn) {
            AppleSignInView(isPresented: $showAppleSignIn)
        }
    }
    
    // Checks if user has completed onboarding and presents Apple Sign-in if not
    private func checkAndPresentAppleSignIn() {
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasOnboarded {
            showAppleSignIn = true
        }
    }
}

struct AppleSignInView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> some UIViewController {
        return SignInViewController(isPresented: $isPresented)
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
    
    class SignInViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            startSignInWithApple()
        }
        
        func startSignInWithApple() {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
        
        // Handle successful authorization
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let idToken = appleIDCredential.identityToken,
               let idTokenString = String(data: idToken, encoding: .utf8) {
                // Extract the ID token and use it to authenticate with your server
                print("Received Apple ID token: \(idTokenString)")
                
                // Call the authenticateWithApple method on the ContentView
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        if let hostingController = rootViewController as? UIHostingController<ContentView> {
                            hostingController.rootView.authenticateWithApple(idToken: idTokenString, presentingController: rootViewController)
                        }
                    }
                }
            }
            
            // Dismiss the sign-in view
            DispatchQueue.main.async {
                self.isPresented = false
            }
        }
        
        // Handle authorization error
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("Apple Sign-in failed: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    if let hostingController = rootViewController as? UIHostingController<ContentView> {
                        hostingController.rootView.presentAlert(title: "Sign-In Failed", message: "Apple sign-in failed. Please try again.", controller: rootViewController)
                    }
                }
                
                self.isPresented = false
            }
        }
        
        // Provide the presentation anchor for the authorization request
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            return self.view.window!
        }
    }
}

extension ContentView {
    func authenticateWithApple(idToken: String, presentingController: UIViewController) {
        // Construct the URL for the authentication endpoint
        guard let url = URL(string: Config.backendURL.appending("/api/v1/auth/signin")) else {
            DispatchQueue.main.async {
                self.presentAlert(title: "Error", message: "Invalid authentication URL.", controller: presentingController)
            }
            return
        }
        
        // Create the request body
        let requestBody = [
            "provider": "apple",
            "id_token": idToken
        ]
        
        // Convert the request body to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            DispatchQueue.main.async {
                self.presentAlert(title: "Error", message: "Failed to prepare sign-in data.", controller: presentingController)
            }
            return
        }
        
        // Create the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Create and resume the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle any network errors
            if let error = error {
                // Check for network connectivity
                if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                    DispatchQueue.main.async {
                        self.presentAlert(title: "No Connection", message: "No internet connection. Please try again.", controller: presentingController)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.presentGenericErrorAlert(controller: presentingController)
                    }
                }
                return
            }
            
            // Check the HTTP response status code
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.presentAlert(title: "Error", message: "Invalid response from server.", controller: presentingController)
                }
                return
            }
            
            if 200...299 ~= httpResponse.statusCode {
                // Success: Parse the response to extract access_token and refresh_token
                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if let accessToken = json["access_token"] as? String,
                               let refreshToken = json["refresh_token"] as? String {
                                // Handle successful authentication
                                // Store tokens securely in Keychain
                                let keychainService = KeychainService()
                                if keychainService.storeTokens(accessToken: accessToken, refreshToken: refreshToken, provider: "apple") {
                                    print("Successfully authenticated and stored tokens.")
                                    // Set flag in UserDefaults to prevent re-triggering the sign-in flow on subsequent launches
                                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                                } else {
                                    DispatchQueue.main.async {
                                        self.presentAlert(title: "Error", message: "Failed to store authentication data.", controller: presentingController)
                                    }
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.presentAlert(title: "Error", message: "Failed to process authentication response.", controller: presentingController)
                        }
                    }
                }
            } else {
                // Handle HTTP error
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let message = json["message"] as? String {
                    // Provider mismatch
                    if httpResponse.statusCode == 400 && message.localizedCaseInsensitiveContains("provider") {
                        DispatchQueue.main.async {
                            self.presentAlert(title: "Sign-In Failed", message: "This account was not created with Apple. Please use the correct sign-in method.", controller: presentingController)
                        }
                    }
                    // Invalid credentials
                    else if httpResponse.statusCode == 400 || httpResponse.statusCode == 401, message.localizedCaseInsensitiveContains("token") || message.localizedCaseInsensitiveContains("credential") {
                        DispatchQueue.main.async {
                            self.presentAlert(title: "Sign-In Failed", message: "Sign-in failed. Invalid credentials.", controller: presentingController)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.presentGenericErrorAlert(controller: presentingController)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.presentGenericErrorAlert(controller: presentingController)
                    }
                }
            }
        }
        
        // Start the request
        task.resume()
    }
    
    private func presentAlert(title: String, message: String, controller: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        DispatchQueue.main.async {
            if controller.presentedViewController == nil {
                controller.present(alert, animated: true)
            }
        }
    }
    
    private func presentGenericErrorAlert(controller: UIViewController) {
        let alert = UIAlertController(title: "Something went wrong", message: "An unexpected error occurred. Would you like to try again?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            // Retry logic can be implemented if needed
        })
        DispatchQueue.main.async {
            if controller.presentedViewController == nil {
                controller.present(alert, animated: true)
            }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
