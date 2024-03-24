//
//  TriangleTests.swift
//  TriangleTests
//
//  Created by Marvin Gajek on 24.03.24.
//

import XCTest
import Metal
@testable import Triangle

final class MetalViewTests: XCTestCase {
    var metalView: MetalView!

    override func setUpWithError() throws {
        try super.setUpWithError()
        metalView = MetalView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    override func tearDownWithError() throws {
        metalView = nil
        try super.tearDownWithError()
    }

    func testMetalViewInitialization() throws {
        XCTAssertNotNil(metalView)
    }
}
