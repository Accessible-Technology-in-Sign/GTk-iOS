//
//  PermissionManager.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/30/24.
//

import AVFoundation

func requestCameraPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { response in
            if response {
                print("Camera access granted")
            } else {
                print("Camera access denied")
            }
        }
    case .denied, .restricted:
        print("Camera access denied")
    case .authorized:
        print("Camera access already granted")
    @unknown default:
        print("Unknown camera permission status")
    }
}
