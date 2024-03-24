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
    float2 textureCoordinate;
};

struct MVP {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex vertex_main(constant Vertex *vertices [[buffer(0)]],
                         constant MVP &mvp [[buffer(1)]],
                         uint vid [[vertex_id]])
{
    Vertex vert = vertices[vid];
    vert.position = mvp.modelViewProjectionMatrix * vert.position;
    return vert;
}

fragment half4 fragment_main(Vertex vert [[stage_in]],
                             texture2d<half> texture [[texture(0)]],
                             sampler texture_sampler [[sampler(0)]])
{
    return texture.sample(texture_sampler, vert.textureCoordinate);
}
