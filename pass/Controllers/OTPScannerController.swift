//
//  QRScannerController.swift
//  pass
//
//  Created by Yishi Lin on 10/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import AVFoundation

class OTPScannerController: QRScannerController {
    
    var tempPassword: Password?
    var scannedOTP: String?
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate Methods
    override func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            supportedCodeTypes.contains(metadataObj.type),
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj) {
            
            // draw a bounds on the found QR code
            qrCodeFrameView?.frame = barCodeObject.bounds
            
            // check whether it is a valid result
            if let scannedString = metadataObj.stringValue {
                if let (accept, message) = delegate?.checkScannedOutput(line: scannedString) {
                    if accept == true {
                        captureSession?.stopRunning()
                        scannedOTP = scannedString
                        tempPassword = Password(name: "empty", url: nil, plainText: scannedString)
                        // set scannerOutput
                        setupOneTimePasswordMessage()
                    } else {
                        scannerOutput.text = message
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
    
    private func setupOneTimePasswordMessage() {
        if let password = tempPassword {
            if password.otpType == .hotp {
                // hotp, no need to refresh
                let (title, content) = password.getOtpStrings()!
                scannerOutput.text = "\(title):\(content)"
            } else if password.otpType == .totp {
                // totp, refresh
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
                    [weak weakSelf = self] timer in
                    let (title, content) = password.getOtpStrings()!
                    weakSelf?.scannerOutput.text = "\(title):\(content)"
                }
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveAddScannedOTPSegue" {
            return tempPassword != nil
        }
        return true
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        super.prepare(for: segue, sender: sender)
//        if segue.identifier == "saveAddScannedOTPSegue" {
//            delegate?.handleScannedOutput(line: scannedOTP)
//        }
//    }
}
