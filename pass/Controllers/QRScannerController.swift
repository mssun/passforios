//
//  QRScannerController.swift
//  pass
//
//  Created by Yishi Lin on 7/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import AVFoundation
import OneTimePassword
import passKit
import SVProgressHUD
import UIKit

protocol QRScannerControllerDelegate: AnyObject {
    func checkScannedOutput(line: String) -> (accepted: Bool, message: String)
    func handleScannedOutput(line: String)
}

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet var scannerOutput: UILabel!

    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?

    let supportedCodeTypes = [AVMetadataObject.ObjectType.qr]

    weak var delegate: QRScannerControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            presentCameraSettings()
        }

        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            scannerOutput.text = "CameraAccessDenied.".localize()
            return
        }
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)

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
            scannerOutput.text = "NoQrCodeDetected.".localize()
            view.bringSubviewToFront(scannerOutput)

            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()

            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubviewToFront(qrCodeFrameView)
            }
        } catch {
            scannerOutput.text = error.localizedDescription
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate Methods

    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        guard let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return setNotDetected()
        }
        guard supportedCodeTypes.contains(metadataObj.type) else {
            return setNotDetected()
        }
        guard let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj) else {
            return setNotDetected()
        }

        // draw a bounds on the found QR code
        qrCodeFrameView?.frame = barCodeObject.bounds

        // check whether it is a valid result
        guard let scanned = metadataObj.stringValue else {
            scannerOutput.text = "NoStringValue".localize()
            return
        }
        guard let (accepted, message) = delegate?.checkScannedOutput(line: scanned) else {
            // no delegate, show the scanned result
            scannerOutput.text = scanned
            return
        }
        scannerOutput.text = message
        guard accepted else {
            return
        }
        captureSession?.stopRunning()
        delegate?.handleScannedOutput(line: scanned)
        DispatchQueue.main.async {
            SVProgressHUD.showSuccess(withStatus: "Done".localize())
            SVProgressHUD.dismiss(withDelay: 1)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func setNotDetected() {
        qrCodeFrameView?.frame = CGRect.zero
        scannerOutput.text = "NoQrCodeDetected.".localize()
    }

    private func presentCameraSettings() {
        let alertController = UIAlertController(
            title: "Error".localize(),
            message: "CameraAccessDenied.".localize() | "WarningToggleCameraPermissionsResetsApp.".localize(),
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel".localize(), style: .default))
        alertController.addAction(UIAlertAction(title: "Settings".localize(), style: .cancel) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        )
        present(alertController, animated: true)
    }
}
