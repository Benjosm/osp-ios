import UIKit

class UploadConfirmationPresenter {
    private weak var presentingViewController: UIViewController?
    private var progressDialog: UIAlertController?
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }
    
    func showUploadConfirmation(for mediaId: String, progress: Double) {
        // If dialog doesn't exist, create it
        if progressDialog == nil {
            let alert = UIAlertController(
                title: "Uploading Media",
                message: "\(Int(progress * 100))% complete",
                preferredStyle: .alert
            )
            
            let progressBar = UIProgressView(progress: Float(progress))
            progressBar.progressViewStyle = .default
            alert.view.addSubview(progressBar)
            
            // Placeholder for progress bar layout; in practice, you'd use constraints
            // For UIAlertController, we use a simple spacer workaround
            alert.setValue(progressBar, forKey: "accessoryView")
            
            presentingViewController?.present(alert, animated: true, completion: nil)
            progressDialog = alert
        } else {
            // Update existing dialog
            if let alert = progressDialog {
                alert.message = "\(Int(progress * 100))% complete"
                if let progressBar = alert.value(forKey: "accessoryView") as? UIProgressView {
                    progressBar.setProgress(Float(progress), animated: true)
                }
            }
        }
    }
    
    func dismissConfirmation() {
        progressDialog?.dismiss(animated: true, completion: nil)
        progressDialog = nil
    }
    
    func showSuccess() {
        guard let alert = progressDialog else { return }
        alert.title = "Upload Successful"
        alert.message = "Your media has been uploaded successfully."
        alert.setValue(nil, forKey: "accessoryView") // Remove progress bar
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismissConfirmation()
        })
    }
    
    func showError() {
        guard let alert = progressDialog else { return }
        alert.title = "Upload Failed"
        alert.message = "We couldn't upload your media. Please try again later."
        alert.setValue(nil, forKey: "accessoryView")
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismissConfirmation()
        })
    }
}
