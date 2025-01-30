//
//  MainView.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/24.
//

import SwiftUI
import MetalKit
import SLRGTk
import MediaPipeTasksVision

class LandmarkStore: ObservableObject {
    @Published var image: UIImage?
    @Published var landmarks: [[SIMD4<Float>]] = [] // Array of hand landmarks (each hand has 21 points)

    private var engine: LiteRTTestEngine = LiteRTTestEngine()

    init() {
        engine.mp.addCallback(name: "ui") { res in
            DispatchQueue.main.async {
                self.landmarks = res.result.landmarks.compactMap { landmarkSet in
                    self.validateAndConvertLandmarks(landmarkSet)
                }
                self.image = res.originalImage
            }
        }
        engine.predictor.addCallback(name: "SignPrinter") { predictions in
            print("Predicted: \(predictions)")
        }
    }

    /// Validates and converts MediaPipe landmarks into an array of `SIMD4<Float>`.
    /// - Parameter landmarkSet: The raw MediaPipe landmark set.
    /// - Returns: An array of 21 `SIMD4<Float>` points if valid, or `nil` if invalid.
    private func validateAndConvertLandmarks(_ landmarkSet: [NormalizedLandmark]) -> [SIMD4<Float>]? {
        // Ensure the landmark set contains exactly 21 points (MediaPipe hand model requirement)
        guard landmarkSet.count == 21 else {
            print("Invalid landmark set: Expected 21 points, got \(landmarkSet.count).")
            return nil
        }

        // Convert landmarks to `SIMD4<Float>` and validate coordinates
        let convertedLandmarks = landmarkSet.map { landmark in
            SIMD4<Float>(landmark.x, landmark.y, landmark.z, 1.0) // Add w-component as 1.0
        }

        // Optional: Add additional validation for coordinate ranges (e.g., x, y in [0, 1])
        let isValid = convertedLandmarks.allSatisfy { point in
            point.x >= 0 && point.x <= 1 &&
            point.y >= 0 && point.y <= 1 &&
            point.z >= -1 && point.z <= 1 // z may be negative (depth)
        }

        if !isValid {
            print("Invalid landmark coordinates detected.")
            return nil
        }

        return convertedLandmarks
    }
}



struct ContentView: View {
    @StateObject private var store = LandmarkStore()

    var body: some View {
            VStack {
                HandLandmarkAnnotator(image: $store.image,
                          landmarks: $store.landmarks,
                          device: MTLCreateSystemDefaultDevice()!)
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .border(Color.gray)
                    .ignoresSafeArea()
            }
        }
}
