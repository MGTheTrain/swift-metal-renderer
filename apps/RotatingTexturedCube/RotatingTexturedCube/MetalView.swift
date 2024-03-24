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
    var position: SIMD4<Float>
    var textureCoordinate: SIMD2<Float>
}

// @ref https://github.com/metal-by-example/sample-code/blob/master/objc/04-DrawingIn3D/DrawingIn3D/MBERenderer.m
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
    private let mathUtils: MathUtils!
    private var texture: MTLTexture!
    private var samplerState: MTLSamplerState!
    private var depthTexture: MTLTexture!
    
    private let vertices: [Vertex] = [
        Vertex(position: SIMD4<Float>(-1, 1, 1, 1), textureCoordinate: SIMD2<Float>(0.0, 1.0)),
        Vertex(position: SIMD4<Float>(-1, -1, 1, 1), textureCoordinate: SIMD2<Float>(0.0, 0.0)),
        Vertex(position: SIMD4<Float>(1, -1, 1, 1), textureCoordinate: SIMD2<Float>(1.0, 0.0)),
        Vertex(position: SIMD4<Float>(1, 1, 1, 1), textureCoordinate: SIMD2<Float>(1.0, 1.0)),
        Vertex(position: SIMD4<Float>(-1, 1, -1, 1), textureCoordinate: SIMD2<Float>(1.0, 1.0)),
        Vertex(position: SIMD4<Float>(-1, -1, -1, 1), textureCoordinate: SIMD2<Float>(1.0, 0.0)),
        Vertex(position: SIMD4<Float>(1, -1, -1, 1), textureCoordinate: SIMD2<Float>(0.0, 0.0)),
        Vertex(position: SIMD4<Float>(1, 1, -1, 1), textureCoordinate: SIMD2<Float>(0.0, 1.0)),
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
        mathUtils = MathUtils()
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        mathUtils = MathUtils()
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        buildDevice()
        buildVertexBuffer()
        buildPipeline()
        self.texture = self.loadTexture(imageName: "surgery.jpg")
        buildSamplerState()
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
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride

        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
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
        let projectionMatrix = mathUtils.matrix_float4x4_perspective(fovyRadians: mathUtils.radians_from_degrees(45.0), aspectRatio: aspectRatio, nearZ: 0.1, farZ: 1000.0)
        let viewMatrix = mathUtils.matrix_float4x4_translation(0.0, 0.0, -20.0)
        let modelMatrix = mathUtils.matrix_float4x4_rotation(angle: rotationAngle, axis: SIMD3<Float>(0.5, 1.0, 0.0))
        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        let mvpBufferSize = MemoryLayout<MVP>.size
        self.mvpBuffer = device.makeBuffer(bytes: [mvpMatrix], length: mvpBufferSize, options: [])
    }
    
    func loadTexture(imageName: String) -> MTLTexture? {
        guard let image = UIImage(named: imageName) else {
            return nil
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        let textureLoader = MTKTextureLoader(device: device)
        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
            return texture
        } catch {
            print("Error loading texture: \(error)")
            return nil
        }
    }
    
    private func buildSamplerState() {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat

        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    func makeDepthTexture() {
        let drawableSize = metalLayer.drawableSize

        guard depthTexture == nil else {
            return
        }

        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                               width: Int(drawableSize.width),
                                                                               height: Int(drawableSize.height),
                                                                               mipmapped: false)

        depthTextureDescriptor.usage = [.renderTarget]
        depthTextureDescriptor.storageMode = .private

        self.depthTexture = device.makeTexture(descriptor: depthTextureDescriptor)
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
        
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float_stencil8,
                                                                              width: Int(drawable.texture.width),
                                                                              height: Int(drawable.texture.height),
                                                                              mipmapped: false)
        depthTextureDescriptor.storageMode = .private
        depthTextureDescriptor.usage = [.renderTarget]
        self.makeDepthTexture()
        renderPass.depthAttachment.texture = depthTexture
        renderPass.depthAttachment.clearDepth = 1.0
        renderPass.depthAttachment.loadAction = .clear
        renderPass.depthAttachment.storeAction = .dontCare
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        // Enable depth testing
        let depthStateDesc = MTLDepthStencilDescriptor()
        depthStateDesc.depthCompareFunction = .less
        depthStateDesc.isDepthWriteEnabled = true
        let depthState = device.makeDepthStencilState(descriptor: depthStateDesc)
        commandEncoder.setDepthStencilState(depthState)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(mvpBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentTexture(texture, index: 0)
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in
            self.mvpBuffer = nil
        }
        commandBuffer.commit()
    }
}
