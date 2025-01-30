//
//  LiteRTTestEngine.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 1/2/25.
//

import Foundation
import UIKit
import MediaPipeTasksVision

public class LiteRTTestEngine {
    public let camera = CameraFeedService()
    public let mp = MPHands(modelPath: Bundle.main.path(forResource: "hand_landmarker", ofType: "task")!)
    public let buffer = Buffer<HandLandmarkerResult>()
    public let predictor: LiteRTPopsignIsolatedSLR
    
    public init() {
        predictor = try! LiteRTPopsignIsolatedSLR(modelPath: Bundle.main.path(forResource: "563-double-lstm-120-cpu", ofType: "tflite")!, mapping: String(contentsOf: Bundle.main.url(forResource: "signsList", withExtension: "txt")!, encoding: .utf8).components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
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
        buffer.addCallback(name: "ModelPusher", callback: {
            result in self.predictor.run(input: PopsignIsolatedSLRInput(result: result))
        })
        camera.poll()
    }
}
