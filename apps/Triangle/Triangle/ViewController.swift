//
//  ViewController.swift
//  Triangle
//
//  Created by Marvin Gajek on 24.03.24.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    var metalView: MTKView!
    var metalRenderer: MetalRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView = MTKView(frame: view.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        view.addSubview(metalView)
        
        guard let metalView = metalView else { return }
        metalRenderer = MetalRenderer(metalView: metalView)
        metalView.delegate = metalRenderer
    }
}
