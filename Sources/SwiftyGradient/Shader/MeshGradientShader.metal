#include <metal_stdlib>
using namespace metal;

struct MeshGradientVertexIn {
    float4 position [[attribute(0)]];
};

struct MeshGradientVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct MeshGradientGrid {
    int width;
    int height;
};

vertex MeshGradientVertexOut meshGradientVertex(MeshGradientVertexIn in [[stage_in]]) {
    MeshGradientVertexOut out;
    out.position = in.position;
    out.uv = (in.position.xy * 0.5) + 0.5; // Convert clip space (-1..1) to uv (0..1)
    return out;
}

// t is a value that goes from 0 to 1 to interpolate in a C1 continuous way across uniformly sampled data points.
// when t is 0, this will return B.  When t is 1, this will return C.  Inbetween values will return an interpolation
// between B and C.  A and B are used to calculate slopes at the edges.
// https://www.paulinternet.nl/?page=bicubic
// https://blog.demofox.org/2015/08/08/cubic-hermite-interpolation/
float cubicInterpolate(float p0, float p1, float p2, float p3, float t) {
    float a = -p0 / 2.0f + (3.0f * p1) / 2.0f - (3.0f * p2) / 2.0f + p3 / 2.0f;
    float b = p0 - (5.0f * p1) / 2.0f + 2.0f * p2 - p3 / 2.0f;
    float c = -p0 / 2.0f + p2 / 2.0f;
    float d = p1;
    
    return a * t * t * t + b * t * t + c * t + d;
}

float4 cubicInterpolateColor(float4 c0, float4 c1, float4 c2, float4 c3, float t) {
    return float4(cubicInterpolate(c0.r, c1.r, c2.r, c3.r, t),
                  cubicInterpolate(c0.g, c1.g, c2.g, c3.g, t),
                  cubicInterpolate(c0.b, c1.b, c2.b, c3.b, t),
                  cubicInterpolate(c0.a, c1.a, c2.a, c3.a, t));
}

// https://github.com/imxieyi/waifu2x-ios/blob/5676e6258e580e5940628811123f8402950013e3/waifu2x/bicubic.metal
fragment float4 meshGradientFragment(MeshGradientVertexOut in [[stage_in]],
                                     constant MeshGradientGrid *grid [[buffer(0)]],
                                     constant float4 *colors [[buffer(1)]]) {
    float2 uv = float2(in.uv.x, 1.0 - in.uv.y);
    int gridWidth = grid -> width;
    int gridHeight = grid -> height;

    float gx = uv.x * (gridWidth - 1);
    float gy = uv.y * (gridHeight - 1);

    int ix = int(floor(gx));
    int iy = int(floor(gy));

    float tx = gx - ix; // fractional part in x
    float ty = gy - iy; // fractional part in y

    int xIdx[4] = {clamp(ix - 1, 0, gridWidth - 1),
                   clamp(ix,     0, gridWidth - 1),
                   clamp(ix + 1, 0, gridWidth - 1),
                   clamp(ix + 2, 0, gridWidth - 1)};

    int yIdx[4] = {clamp(iy - 1, 0, gridHeight - 1),
                   clamp(iy,     0, gridHeight - 1),
                   clamp(iy + 1, 0, gridHeight - 1),
                   clamp(iy + 2, 0, gridHeight - 1)};

    float4 colInterp[4];
    for (int j = 0; j < 4; j++) {
        float4 c0 = colors[yIdx[j] * gridWidth + xIdx[0]];
        float4 c1 = colors[yIdx[j] * gridWidth + xIdx[1]];
        float4 c2 = colors[yIdx[j] * gridWidth + xIdx[2]];
        float4 c3 = colors[yIdx[j] * gridWidth + xIdx[3]];
        colInterp[j] = clamp(cubicInterpolateColor(c0, c1, c2, c3, tx), 0.0f, 255.0f);
    }

    float4 finalColor = cubicInterpolateColor(colInterp[0], colInterp[1], colInterp[2], colInterp[3], ty);

    // How to (and how not to) fix color banding - https://blog.frost.kiwi/GLSL-noise-and-radial-gradient/
    float noise = fract(52.9829189 * fract(dot(in.position.xy, float2(0.06711056, 0.00583715))));
    finalColor.rgb += (1.0 / 255.0) * noise - (0.5 / 255.0);
    
    return finalColor;
}

