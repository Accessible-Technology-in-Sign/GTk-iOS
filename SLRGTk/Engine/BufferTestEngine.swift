//
//  CameraTestEngine.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/24

import Foundation
import UIKit
import MediaPipeTasksVision

public class BufferTestEngine {
    public let camera = CameraFeedService()
    public let mp = MPHands(modelPath: Bundle.main.path(forResource: "hand_landmarker", ofType: "task")!)
    public let buffer = Buffer<HandLandmarkerResult>()
    public init() {
        requestCameraPermission()
        camera.addCallback(name: "ImageReceiver", callback: {
            image in
            self.mp.run(input: MPVisionInput(image: image, timestamp: Int64(Date().timeIntervalSince1970 * 1000)))
        })
        mp.addCallback(name: "LandmarkPrinter", callback:{
            result in print("Landmarks: \(result)")
        })
        mp.addCallback(name: "BufferLoader", callback: {
            result in
            if (result.result.landmarks.count > 0) {
                self.buffer.addElement(elem: result.result)
            }
        })
        buffer.addCallback(name: "BufferPrinter", callback: {
            result in print("Buffer: \(result.count)")
        })
        camera.poll()
    }
}
