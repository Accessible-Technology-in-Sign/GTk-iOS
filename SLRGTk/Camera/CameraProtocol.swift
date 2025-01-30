import Foundation
import CoreMedia
import AVFoundation
import UIKit

public protocol CameraProtocol {
    associatedtype T
    
    func poll()
    func pause()
}

public class CameraFeedService: CallbackManager<UIImage>, CameraProtocol {
    // MARK: - Camera Configuration
    private var cameraPosition: AVCaptureDevice.Position = .front // Default to front camera
    private var session: AVCaptureSession!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var isSessionRunning = false
    
    weak var delegate: CameraFeedService?

    // MARK: - Initialization
    override init() {
        super.init()
        session = AVCaptureSession()
        videoDataOutput = AVCaptureVideoDataOutput()
        
        // Request camera access and configure session
        requestCameraAccess { [weak self] granted in
            guard granted else { return }
            self?.configureSession()
            self?.startSession()
        }
    }

    public func poll() {
        startSession()
    }

    public func pause() {
        stopSession()
    }

    // MARK: - Camera Management
    private func configureSession() {
        session.beginConfiguration()
        
        // Add camera input
        guard let camera = getCamera(for: cameraPosition) else { return }
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            }
        } catch {
            print("Error adding video device input: \(error)")
        }

        // Add video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        }

        session.commitConfiguration()
    }
    
    private func getCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
    
    private let sessionQueue = DispatchQueue(label: "edu.gatech.ccg.slrgtk")
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    // MARK: - Camera Access
    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}

// MARK: - Camera Delegate
extension CameraFeedService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Set video orientation based on device orientation
        connection.videoOrientation = currentVideoOrientation()

        // Mirror video for front camera if necessary
        connection.isVideoMirrored = (cameraPosition == .front)

        // Convert CMSampleBuffer to UIImage with correct orientation
        if let image = UIImage.from(sampleBuffer: sampleBuffer, orientation: connection.videoOrientation.toUIImageOrientation()) {
            triggerCallbacks(with: image)
        }
    }
}

// MARK: - Extensions for Orientation Handling

extension UIDeviceOrientation {
    /// Maps `UIDeviceOrientation` to `AVCaptureVideoOrientation`
    func toVideoOrientation() -> AVCaptureVideoOrientation? {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight // Camera's landscapeLeft is device's landscapeRight
        case .landscapeRight:
            return .landscapeLeft // Camera's landscapeRight is device's landscapeLeft
        default:
            return nil
        }
    }
}

extension AVCaptureVideoOrientation {
    /// Maps `AVCaptureVideoOrientation` to `UIImage.Orientation`
    func toUIImageOrientation() -> UIImage.Orientation {
        switch self {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeRight:
            return .down
        case .landscapeLeft:
            return .up
        @unknown default:
            return .up
        }
    }
}

extension UIImage {
    /// Converts a CMSampleBuffer into a UIImage with the specified orientation.
    static func from(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation = .up) -> UIImage? {
        // Get the pixel buffer from the sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create a UIImage from the CIImage with the specified orientation
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        }
        
        return nil
    }
}

// MARK: - Helper Methods for Video Orientation

extension CameraFeedService {
    
    /// Determines the current video orientation based on the device's orientation.
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        guard let deviceOrientation = UIDevice.current.orientation.toVideoOrientation() else {
            return .portrait // Default to portrait if orientation is unknown or invalid.
        }
        
        return deviceOrientation
    }
}
