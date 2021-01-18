import UIKit
import passKit
import SVProgressHUD

class PasswordManager {
    weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func providePasswordPasteboard(with passwordPath: String) {
        guard let viewController = viewController else {
            return
        }
        decryptPassword(in: viewController, with: passwordPath) { password in
            SecurePasteboard.shared.copy(textToCopy: password.password)
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.dark)
            SVProgressHUD.showSuccess(withStatus: "PasswordCopiedToPasteboard.".localize())
            SVProgressHUD.dismiss(withDelay: 1)
        }
    }

    func addPassword(with password: Password) {
        guard let viewController = viewController else {
            return
        }

        encryptPassword(in: viewController, with: password) {
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.showSuccess(withStatus: "Done".localize())
            SVProgressHUD.dismiss(withDelay: 1)
        }
    }
}
