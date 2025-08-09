import SwiftUI
import AuthenticationServices
import UIKit

struct SignInView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showErrorAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var idToken: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "applelogo")
                .font(.system(size: 60))
                .foregroundColor(.black)

            Text("Welcome")
                .font(.title)
                .fontWeight(.semibold)

            Text("Sign in with Apple to continue")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            SignInWithAppleButton(idToken: $idToken)
                .frame(height: 50)
                .padding(.horizontal)
        }
        .padding()
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: idToken) { _, value in
            if let token = value {
                authenticateWithBackend(idToken: token)
            }
        }
    }

    private func authenticateWithBackend(idToken: String) {
        guard let url = URL(string: Config.backendURL.appending("/api/v1/auth/signin")) else {
            showAlert("Error", "Invalid authentication URL.")
            return
        }

        let requestBody = ["provider": "apple", "id_token": idToken]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            showAlert("Error", "Failed to prepare sign-in data.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == NSURLErrorNotConnectedToInternet {
                        self?.showAlert("No Connection", "Please check your internet connection and try again.")
                    } else {
                        self?.showGenericError()
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showAlert("Error", "Invalid response from server.")
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let accessToken = json["access_token"] as? String,
                       let refreshToken = json["refresh_token"] as? String {
                        let keychain = KeychainService()
                        if keychain.storeTokens(accessToken: accessToken, refreshToken: refreshToken, provider: "apple") {
                            self?.hasCompletedOnboarding = true
                        } else {
                            self?.showAlert("Error", "Failed to store authentication data.")
                        }
                    } else {
                        self?.showAlert("Error", "Failed to process authentication response.")
                    }
                } else {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let message = json["message"] as? String {
                        if httpResponse.statusCode == 400 && message.localizedCaseInsensitiveContains("provider") {
                            self?.showAlert("Sign-In Failed", "This account was not created with Apple. Please use the correct sign-in method.")
                        } else if httpResponse.statusCode == 401 || (httpResponse.statusCode == 400 && message.localizedCaseInsensitiveContains("token")) {
                            self?.showAlert("Sign-In Failed", "Invalid credentials. Please try again.")
                        } else {
                            self?.showGenericError()
                        }
                    } else {
                        self?.showGenericError()
                    }
                }
            }
        }.resume()
    }

    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showErrorAlert = true
    }

    private func showGenericError() {
        alertTitle = "Something went wrong"
        alertMessage = "An unexpected error occurred. Please try again."
        showErrorAlert = true
    }
}

// MARK: - SignInWithAppleButton
struct SignInWithAppleButton: UIViewRepresentable {
    @Binding var idToken: String?

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.startSignInWithApple), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator($idToken)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        var idTokenBinding: Binding<String?>

        init(_ idTokenBinding: Binding<String?>) {
            self.idTokenBinding = idTokenBinding
        }

        @objc func startSignInWithApple() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let idToken = appleIDCredential.identityToken,
               let idTokenString = String(data: idToken, encoding: .utf8) {
                idTokenBinding.wrappedValue = idTokenString
            } else {
                DispatchQueue.main.async {
                    // Optionally handle token decode failure with alert
                }
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            DispatchQueue.main.async {
                // Optionally surface this, but alerting too soon may clash with presentation
            }
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.windows.first!
        }
    }
}
