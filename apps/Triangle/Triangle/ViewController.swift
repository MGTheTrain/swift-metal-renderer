//
//  ViewController.swift
//  Triangle
//
//  Created by Marvin Gajek on 24.03.24.
//

import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create MetalView
        let metalView = MetalView(frame: view.bounds)
        view.addSubview(metalView)
    }
}
