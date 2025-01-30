//
//  CameraTestEngine.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/
import Foundation
import UIKit

public class CameraTestEngine {
    public let camera = CameraFeedService()
    
    public init() {
        requestCameraPermission()
        camera.poll()
    }
}
