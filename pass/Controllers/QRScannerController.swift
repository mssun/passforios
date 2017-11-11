//
//  QRScannerController.swift
//  pass
//
//  Created by Yishi Lin on 7/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import AVFoundation
import OneTimePassword
import SVProgressHUD

protocol QRScannerControllerDelegate {
    func checkScannedOutput(line: String) -> (accept: Bool, message: String)
    func handleScannedOutput(line: String)
}

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var scannerOutput: UILabel!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    let supportedCodeTypes = [AVMetadataObject.ObjectType.qr]
    
    var delegate: QRScannerControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()

            // Set the input device on the capture session.
            captureSession?.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            // Start video capture.
            captureSession?.startRunning()
            
            // Move the message label to the front
            scannerOutput.layer.cornerRadius = 10
            scannerOutput.text = "No QR code detected"
            view.bringSubview(toFront: scannerOutput)
            
            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
            
        } catch {
            print(error)
            return
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate Methods
    
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            supportedCodeTypes.contains(metadataObj.type),
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj) {
            
            // draw a bounds on the found QR code
            qrCodeFrameView?.frame = barCodeObject.bounds
            
            // check whether it is a valid result
            if let scanned = metadataObj.stringValue {
                if let (accept, message) = delegate?.checkScannedOutput(line: scanned) {
                    scannerOutput.text = message
                    if accept == true {
                        captureSession?.stopRunning()
                        delegate?.handleScannedOutput(line: scanned)
                        DispatchQueue.main.async {
                            SVProgressHUD.showSuccess(withStatus: "Done")
                            SVProgressHUD.dismiss(withDelay: 1)
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                } else {
                    // no delegate, show the scanned result
                    scannerOutput.text = scanned
                }
            } else {
                scannerOutput.text = "No string value"
            }
            
        } else {
            qrCodeFrameView?.frame = CGRect.zero
            scannerOutput.text = "No QR code detected"
        }
    }
}
