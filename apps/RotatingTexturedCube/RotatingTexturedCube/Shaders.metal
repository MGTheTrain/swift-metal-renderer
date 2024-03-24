//
//  Shaders.metal
//  RotatingTexturedCube
//
//  Created by Marvin Gajek on 24.03.24.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
};

struct MVP {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex vertex_main(constant float4 *position [[buffer(0)]],
                          constant MVP &mvp [[buffer(1)]],
                          uint vid [[vertex_id]])
{
    Vertex vert;
    vert.position = mvp.modelViewProjectionMatrix * position[vid];
    return vert;
}

fragment float4 fragment_main(Vertex vert [[stage_in]])
{
    return float4(0.0, 0.0, 1.0, 1.0);
}
