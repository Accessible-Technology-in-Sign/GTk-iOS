//
//  ModelProtocol.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/30/24.
//

import UIKit
import MediaPipeTasksVision
import AVFoundation
import TensorFlowLite

protocol ModelProtocol {
    associatedtype I
    
    func run(input: I)
}

// Data classes
public struct MPVisionInput {
    public let image: UIImage
    public let timestamp: Int64
}

public struct MPHandsOutput {
    public let originalImage: UIImage
    public let result: HandLandmarkerResult
}

// MPHands Class
public class MPHands: CallbackManager<MPHandsOutput>, ModelProtocol {
    typealias I = MPVisionInput
    private let modelPath: String
    private let runningMode: RunningMode
    private let numHands: Int
    private let minHandDetectionConfidence: Float
    private let minTrackingConfidence: Float
    private let minHandPresenceConfidence: Float
    private var outputInputLookup: [Int64: UIImage] = [:]

    private lazy var handLandmarker: HandLandmarker = {
        let options = HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = runningMode
        options.numHands = numHands
        options.minHandDetectionConfidence = minHandDetectionConfidence
        options.minTrackingConfidence = minTrackingConfidence
        options.minHandPresenceConfidence = minHandPresenceConfidence
        
        if runningMode == .liveStream {
            options.handLandmarkerLiveStreamDelegate = self
        }
        
        do {
            return try HandLandmarker(options: options)
        } catch {
            fatalError("Failed to initialize HandLandmarker: \(error)")
        }
    }()

    init(modelPath: String,
         runningMode: RunningMode = .liveStream,
         numHands: Int = 1,
         minHandDetectionConfidence: Float = 0.5,
         minTrackingConfidence: Float = 0.5,
         minHandPresenceConfidence: Float = 0.5) {
        self.modelPath = modelPath
        self.runningMode = runningMode
        self.numHands = numHands
        self.minHandDetectionConfidence = minHandDetectionConfidence
        self.minTrackingConfidence = minTrackingConfidence
        self.minHandPresenceConfidence = minHandPresenceConfidence
        super.init()
    }


    public func run(input: MPVisionInput) {
        let mpImage = try? MPImage(uiImage: input.image)
        guard let image = mpImage else { return }

        switch runningMode {
        case .liveStream:
            outputInputLookup[input.timestamp] = input.image
            try? handLandmarker.detectAsync(image: image, timestampInMilliseconds: Int(input.timestamp))

        case .image:
            if let result = try? handLandmarker.detect(image: image) {
                let output = MPHandsOutput(originalImage: input.image, result: result)
                triggerCallbacks(with: output)
            }

        case .video:
            if let result = try? handLandmarker.detect(videoFrame: image, timestampInMilliseconds: Int(input.timestamp)) {
                let output = MPHandsOutput(originalImage: input.image, result: result)
                triggerCallbacks(with: output)
            }
        @unknown default:
            break
        }
    }
}

extension MPHands: HandLandmarkerLiveStreamDelegate {
    public func handLandmarker(_ handLandmarker: HandLandmarker,
                        didFinishDetection result: HandLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        guard let result = result, let originalImage = outputInputLookup[Int64(timestampInMilliseconds)] else { return }

        let output = MPHandsOutput(originalImage: originalImage, result: result)
        triggerCallbacks(with: output)

        outputInputLookup.removeValue(forKey: Int64(timestampInMilliseconds))

        let oldTimestamps = outputInputLookup.keys.filter { $0 < Int64(timestampInMilliseconds) }

        for oldTimestamp in oldTimestamps {
            outputInputLookup.removeValue(forKey: oldTimestamp)
        }
    }
}

public struct ClassPredictions {
    let classes: [String]
    let probabilities: [Float]
}

public struct PopsignIsolatedSLRInput {
    let result: [HandLandmarkerResult]
}

public class LiteRTPopsignIsolatedSLR: CallbackManager<ClassPredictions>, ModelProtocol {
    // Use private(set) to prevent external modification while maintaining access
    private(set) var interpreter: Interpreter
    private let mapping: [String]

    public init(modelPath: String, mapping: [String]) throws {
        self.mapping = mapping
        var options = Interpreter.Options()
        options.threadCount = 1
        
        self.interpreter = try Interpreter(modelPath: modelPath, options: options)
        try self.interpreter.allocateTensors()
    }

    public func run(input: PopsignIsolatedSLRInput) {
        autoreleasepool {
            let inputArray = getInputArray(input: input)
            let inputData = Data(copyingBufferOf: inputArray)
            
            do {
                try interpreter.copy(inputData, toInputAt: 0)
                try interpreter.invoke()
                
                triggerCallbacks(with: ClassPredictions(
                    classes: mapping,
                    probabilities: try interpreter.output(at: 0).data.toArray()
                ))
            
            } catch {
                print("Interpreter error: \(error.localizedDescription)")
            }
        }
    }
    
    private func getInputArray(input: PopsignIsolatedSLRInput) -> [Float] {
        var flattenedArray: [Float] = []
        
        for handResult in input.result {
            if let landmarks = handResult.landmarks.first {
                for landmark in landmarks {
                    flattenedArray.append(Float(landmark.x))
                    flattenedArray.append(Float(landmark.y))
                }
            }
        }
        
        return flattenedArray
    }

}

// MARK: - Extensions
extension Data {
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
    
    func toArray() throws -> [Float] {
        guard count >= MemoryLayout<Float>.stride else {
            throw NSError(domain: "DataConversionError",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Insufficient data size"])
        }
        
        let capacity = count / MemoryLayout<Float>.stride
        return withUnsafeBytes { pointer in
            let typed = pointer.bindMemory(to: Float.self)
            return Array(typed.prefix(capacity))
        }
    }
}

