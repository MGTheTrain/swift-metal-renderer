//
//  Matrix.swift
//  RotatingTexturedCube
//
//  Created by Marvin Gajek on 24.03.24.
//

import simd

struct MathUtils {
    func matrix_float4x4_rotation(angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
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
