//
//  MetalRenderer.swift
//  Triangle
//
//  Created by Marvin Gajek on 24.03.24.
//

import UIKit
import Metal
import MetalKit

class MetalView: UIView {
    private var displayLink: CADisplayLink?
    private var metalLayer: CAMetalLayer!
    private var device: MTLDevice!
    private var pipeline: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var positionBuffer: MTLBuffer!
    
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
        buildVertexBuffers()
        buildPipeline()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let superview = superview {
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
    
    private func buildVertexBuffers() {
        let positions: [Float] = [
            0.0,  0.5, 0, 1,
            -0.5, -0.5, 0, 1,
            0.5, -0.5, 0, 1
        ]
        
        positionBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<Float>.size * positions.count, options: [])
    }
    
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        redraw()
    }
    
    private func redraw() {
        guard let drawable = metalLayer.nextDrawable() as? CAMetalDrawable else {
            return
        }
        
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
        commandEncoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
