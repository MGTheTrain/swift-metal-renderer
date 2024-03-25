//
//  MetalRenderer.swift
//  Triangle
//
//  Created by Marvin Gajek on 24.03.24.
//

import UIKit
import Metal
import MetalKit

/*
 @class MetalView
 @abstract A UIView subclass for rendering with Metal.
 */
class MetalView: UIView {
    private var displayLink: CADisplayLink?
    private var metalLayer: CAMetalLayer!
    private var device: MTLDevice!
    private var pipeline: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var positionBuffer: MTLBuffer!
    
    /*
     @method layerClass
     @abstract Specifies the Core Animation layer class for MetalView.
     @return The CAMetalLayer class.
     */
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    /*@method init(frame:)
    @abstract Initializes the Metal view with the specified frame rectangle.
    @param frame The frame rectangle for the view, measured in points.
    @return An initialized Metal view object.
    */
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    /*
     @method init(coder:)
     @abstract Initializes the Metal view from data in a given unarchiver.
     @param aDecoder An unarchiver object.
     @return An initialized Metal view object, or nil if the object could not be unarchived.
     */
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    /*
     @method commonInit
     @abstract Initializes Metal-related components.
    */
    private func commonInit() {
        self.setupDevice()
        self.setupVertexBuffers()
        self.setupPipeline()
    }
    
    /*
     @method didMoveToSuperview
     @abstract Notifies the view that it was added to a superview.
     */
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let superview = superview {
            self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
            self.displayLink?.add(to: .main, forMode: .common)
        } else {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }
    
    /*
     @method setupDevice
     @abstract Sets up Metal device.
    */
    private func setupDevice() {
        self.device = MTLCreateSystemDefaultDevice()
        self.metalLayer = layer as? CAMetalLayer
        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.contentsScale = UIScreen.main.scale
    }
    
    /*
     @method setupPipeline
     @abstract Setup the rendering pipeline.
    */
    private func setupPipeline() {
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
            self.pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error occurred when creating render pipeline state: \(error)")
        }
        
        self.commandQueue = device.makeCommandQueue()
    }
    
    /*
     @method setupVertexBuffers
     @abstract Setup vertex buffers.
    */
    private func setupVertexBuffers() {
        let positions: [Float] = [
            0.0,  0.5, 0, 1,
            -0.5, -0.5, 0, 1,
            0.5, -0.5, 0, 1
        ]
        
        self.positionBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<Float>.size * positions.count, options: [])
    }
    
    /*
     @method displayLinkDidFire:
     @abstract Responds to the display link firing.
     @param displayLink The CADisplayLink object associated with the event.
    */
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        self.redraw()
    }
    
    /*
     @method redraw
     @abstract Redraws the Metal content.
    */
    private func redraw() {
        guard let drawable = self.metalLayer.nextDrawable() as? CAMetalDrawable else {
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
