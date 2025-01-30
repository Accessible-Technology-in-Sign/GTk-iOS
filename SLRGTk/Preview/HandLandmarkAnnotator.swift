//
//  HandLandmarkAnnotator.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/24.
//

import MetalKit
import UIKit

struct Dimensions {
    var viewWidth: Float
    var viewHeight: Float
    var imageWidth: Float
    var imageHeight: Float
}

public class HandLandmarkAnnotatorShader {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private var pointBuffer: MTLBuffer
    private var dimensionsBuffer: MTLBuffer?
    private var textureLoader: MTKTextureLoader

    private var texture: MTLTexture?
    private var samplerState: MTLSamplerState?

    private var landmarksPresent: Int32 = 0 // 1 if landmarks are present, 0 otherwise
    private var points = [SIMD4<Float>](repeating: SIMD4<Float>(0, 0, 0, 0), count: 21)

    var pointColor = SIMD4<Float>(1, 0, 0, 1) // Red
    var lineColor = SIMD4<Float>(0, 0, 1, 1) // Blue
    var radius: Float = 0.0075
    var strokeWidth: Float = 0.005

    public init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        // Load shader functions from the default library
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4 // Position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2 // UV coordinates
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 6

        // Create render pipeline descriptor and state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        // Vertex buffer (quad for rendering the image)
        let vertices: [Float] = [
            -1, -1, 0, 1,   0, 1,
             1, -1, 0, 1,   1, 1,
            -1,  1, 0, 1,   0, 0,
             1,  1, 0, 1,   1, 0,
        ]
        self.vertexBuffer = device.makeBuffer(bytes: vertices,
                                              length: vertices.count * MemoryLayout<Float>.size,
                                              options: [])!

        // Point buffer (for landmark positions)
        self.pointBuffer = device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.size * points.count,
                                             options: [])!

        // Texture loader for input images
        self.textureLoader = MTKTextureLoader(device: device)

        // Sampler state for texture sampling
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        self.samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    public func updateImage(_ image: UIImage?) {
        guard let cgImage = image?.cgImage else { return }
        
        do {
            texture = try textureLoader.newTexture(cgImage: cgImage)
            print("Texture loaded successfully.")
        } catch {
            print("Failed to load texture:", error.localizedDescription)
            texture = nil
        }
    }

    public func updateLandmarks(_ newLandmarksSets: [[SIMD4<Float>]]) {
        guard let firstHandLandmarksSet = newLandmarksSets.first(where: { $0.count == points.count }) else {
            landmarksPresent = 0 // No valid landmarks found.
            return
        }
        
        points = firstHandLandmarksSet // Use the first valid set of landmarks.
        
        pointBuffer.contents().copyMemory(from: points,
                                          byteCount: MemoryLayout<SIMD4<Float>>.size * points.count)
        
        landmarksPresent = !points.isEmpty ? Int32(1) : Int32(0)
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let texture else { return }

        // Update dimensions
        var dimensions = Dimensions(
            viewWidth: Float(view.drawableSize.width),
            viewHeight: Float(view.drawableSize.height),
            imageWidth: Float(texture.width),
            imageHeight: Float(texture.height)
        )
        
        if dimensionsBuffer == nil {
            dimensionsBuffer = device.makeBuffer(length: MemoryLayout<Dimensions>.size, options: [])
        }
        
        memcpy(dimensionsBuffer?.contents(), &dimensions, MemoryLayout<Dimensions>.size)

        // Create a command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()!

        // Create a render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)

        // Set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Set fragment resources
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentBytes(&pointColor, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        renderEncoder.setFragmentBytes(&lineColor, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
        renderEncoder.setFragmentBytes(&radius, length: MemoryLayout<Float>.size, index: 2)
        renderEncoder.setFragmentBytes(&strokeWidth, length: MemoryLayout<Float>.size, index: 3)
        
        if let dimensionsBuffer = dimensionsBuffer {
            renderEncoder.setFragmentBuffer(dimensionsBuffer, offset: 0, index: 4)
        }

        renderEncoder.setFragmentBuffer(pointBuffer, offset: 0, index: 5)
        renderEncoder.setFragmentBytes(&landmarksPresent, length: MemoryLayout<Int32>.size, index: 6)

        if let samplerState = samplerState {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        }

        // Draw the textured quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        // End encoding and commit the command buffer
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

}

import SwiftUI

public struct HandLandmarkAnnotator: UIViewRepresentable {
    @Binding var image: UIImage?
    @Binding var landmarks: [[SIMD4<Float>]] // Array of hand landmarks
    let device: MTLDevice
    
    public init(image: Binding<UIImage?>, landmarks: Binding<[[SIMD4<Float>]]>, device: MTLDevice) {
        self._image = image
        self._landmarks = landmarks
        self.device = device
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 60
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer.updateImage(image)
        context.coordinator.renderer.updateLandmarks(landmarks)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(device: device)
    }

    public class Coordinator: NSObject, MTKViewDelegate {
        let renderer: HandLandmarkAnnotatorShader

        public init(device: MTLDevice) {
            self.renderer = HandLandmarkAnnotatorShader(device: device)
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
    }
}
