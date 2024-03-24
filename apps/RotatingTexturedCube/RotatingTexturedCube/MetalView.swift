//
//  MetalView.swift
//  RotatingTexturedCube
//
//  Created by Marvin Gajek on 24.03.24.
//

import UIKit
import Metal
import MetalKit
import simd

struct MVP {
    var modelViewProjectionMatrix: matrix_float4x4
}

struct Vertex {
    var position: (Float, Float, Float, Float)
}

class MetalView: UIView {
    private var displayLink: CADisplayLink?
    private var metalLayer: CAMetalLayer!
    private var device: MTLDevice!
    private var pipeline: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var mvpBuffer: MTLBuffer!
    private var rotationAngle: Float = 0
    
    private let vertices: [Vertex] = [
        Vertex(position: (-1, 1, 1, 1)),
        Vertex(position: (-1, -1, 1, 1)),
        Vertex(position: (1, -1, 1, 1)),
        Vertex(position: (1, 1, 1, 1)),
        Vertex(position: (-1, 1, -1, 1)),
        Vertex(position: (-1, -1, -1, 1)),
        Vertex(position: (1, -1, -1, 1)),
        Vertex(position: (1, 1, -1, 1)),
    ]
    
    private let indices: [UInt16] = [
        3, 2, 6, 6, 7, 3,
        4, 5, 1, 1, 0, 4,
        4, 0, 3, 3, 7, 4,
        1, 5, 6, 6, 2, 1,
        0, 1, 2, 2, 3, 0,
        7, 6, 5, 5, 4, 7
    ]
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        buildDevice()
        buildVertexBuffer()
        buildPipeline()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
            displayLink?.add(to: .main, forMode: .common)
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    private func buildDevice() {
        device = MTLCreateSystemDefaultDevice()
        metalLayer = layer as? CAMetalLayer
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.contentsScale = UIScreen.main.scale
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "vertex_main"),
              let fragmentFunc = library.makeFunction(name: "fragment_main") else {
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error occurred when creating render pipeline state: \(error)")
        }
        
        commandQueue = device.makeCommandQueue()
    }
    
    private func buildVertexBuffer() {
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])
        self.indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: [])
    }
    
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        rotationAngle += 0.01
        redraw()
    }
    
    private func buildMVPBuffer() {
        let aspectRatio = Float(bounds.width / bounds.height)
        let projectionMatrix = matrix_float4x4_perspective(fovyRadians: radians_from_degrees(45.0), aspectRatio: aspectRatio, nearZ: 0.1, farZ: 1000.0)
        let viewMatrix = matrix_float4x4_translation(0.0, 0.0, -20.0)
        let modelMatrix = matrix_float4x4_rotation(angle: rotationAngle, axis: SIMD3<Float>(0.5, 1.0, 0.0))
        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        var mvpData = MVP(modelViewProjectionMatrix: mvpMatrix)
        let mvpBufferSize = MemoryLayout<MVP>.size
        self.mvpBuffer = device.makeBuffer(bytes: [mvpMatrix], length: mvpBufferSize, options: [])
    }
    
    private func redraw() {
        guard let drawable = metalLayer.nextDrawable() else {
            return
        }
        
        buildMVPBuffer()
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(mvpBuffer, offset: 0, index: 1)
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in
            self.mvpBuffer = nil
        }
        commandBuffer.commit()
    }
    
    private func matrix_float4x4_rotation(angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c
        let x = axis.x, y = axis.y, z = axis.z

        let col1 = SIMD4<Float>(t*x*x + c,     t*x*y - z*s,   t*x*z + y*s,   0)
        let col2 = SIMD4<Float>(t*x*y + z*s,   t*y*y + c,     t*y*z - x*s,   0)
        let col3 = SIMD4<Float>(t*x*z - y*s,   t*y*z + x*s,   t*z*z + c,     0)
        let col4 = SIMD4<Float>(0,             0,             0,             1)

        return matrix_float4x4(columns: (col1, col2, col3, col4))
    }
    
    func matrix_float4x4_perspective(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> float4x4 {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        return float4x4(
            [xScale, 0, 0, 0],
            [0, yScale, 0, 0],
            [0, 0, zScale, -1],
            [0, 0, wzScale, 0]
        )
    }

    func radians_from_degrees(_ degrees: Float) -> Float {
        return degrees * .pi / 180.0
    }

    func matrix_float4x4_translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [x, y, z, 1]
        )
    }
}