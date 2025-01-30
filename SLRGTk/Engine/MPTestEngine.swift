//
//  CameraTestEngine.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/
import Foundation
import UIKit

public class MPTestEngine {
    public let camera = CameraFeedService()
    public let mp = MPHands(modelPath: Bundle.main.path(forResource: "hand_landmarker", ofType: "task")!)
//    public var onResultUpdate: ((MPHandsOutput) -> Void)? {
//        didSet {
//            mp.removeCallback(name: "LandmarkReceiver")
//            if let callback = onResultUpdate {
//                mp.addCallback(name: "LandmarkReceiver", callback: callback)
//            }
//        }
//    }
    
    public init() {
        requestCameraPermission()
        camera.addCallback(name: "ImageReceiver", callback: {
            image in
            self.mp.run(input: MPVisionInput(image: image, timestamp: Int64(Date().timeIntervalSince1970 * 1000)))
        })
//        mp.addCallback(name: "LandmarkPrinter", callback:{
//            result in print("Landmarks: \(result)")
//        })
        camera.poll()
    }
}
