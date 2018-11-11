//
//  QRScannerController.swift
//  pass
//
//  Created by Yishi Lin on 10/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import AVFoundation
import passKit

class OTPScannerController: QRScannerController {
    
    var scannedOTP: String?
    
    @IBAction func pressCancel(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }
    // MARK: - AVCaptureMetadataOutputObjectsDelegate Methods
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            supportedCodeTypes.contains(metadataObj.type),
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj) {
            
            // draw a bounds on the found QR code
            qrCodeFrameView?.frame = barCodeObject.bounds
            
            // check whether it is a valid result
            if let scannedString = metadataObj.stringValue {
                if let (accept, message) = delegate?.checkScannedOutput(line: scannedString) {
                    scannerOutput.text = message
                    if accept == true {
                        captureSession?.stopRunning()
                        scannedOTP = scannedString
                        presentSaveAlert()
                    }
                } else {
                    // no delegate, show the scanned result
                    scannerOutput.text = scannedString
                }
            } else {
                scannerOutput.text = "No string value"
            }
            
        } else {
            qrCodeFrameView?.frame = CGRect.zero
            scannerOutput.text = "No QR code detected"
        }
    }
    
    private func presentSaveAlert() {
        // initialize alert
        // XXX: use Password class for now, we need to come up a better structure to oranize this
        let password = Password(name: "empty", url: URL(string: ".")!, plainText: scannedOTP!)
        let (title, content) = password.getOtpStrings()!
        let alert = UIAlertController(title: "Success", message: "\(title): \(content)", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.default, handler: {[unowned self] (action) -> Void in
            self.delegate?.handleScannedOutput(line: self.scannedOTP!)
            self.navigationController?.popViewController(animated: true)
        }))
        
        if password.otpType == .hotp {
            // hotp, no need to refresh
            self.present(alert, animated: true, completion: nil)
        } else if password.otpType == .totp {
            // totp, refresh otp
            self.present(alert, animated: true) {
                let alertController = self.presentedViewController as! UIAlertController
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {_ in 
                    let (title, content) = password.getOtpStrings()!
                    alertController.message = "\(title): \(content)"
                }
            }
        }
    }
}
