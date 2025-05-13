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

// How to (and how not to) fix color banding - https://blog.frost.kiwi/GLSL-noise-and-radial-gradient/
float gradientNoise(float2 uv) {
    return fract(52.9829189 * fract(dot(uv, float2(0.06711056, 0.00583715))));
}

vertex MeshGradientVertexOut meshGradientVertex(MeshGradientVertexIn in [[stage_in]]) {
    MeshGradientVertexOut out;
    out.position = in.position;
    out.uv = (in.position.xy * 0.5) + 0.5; // Convert clip space (-1..1) to uv (0..1)
    return out;
}

float cubicInterpolate(float p0, float p1, float p2, float p3, float t) {
    float a0 = p3 - p2 - p0 + p1;
    float a1 = p0 - p1 - a0;
    float a2 = p2 - p0;
    float a3 = p1;
    float t2 = t * t;
    return a0 * t * t2 + a1 * t2 + a2 * t + a3;
}

float4 cubicInterpolateColor(float4 c0, float4 c1, float4 c2, float4 c3, float t) {
    return float4(cubicInterpolate(c0.r, c1.r, c2.r, c3.r, t),
                  cubicInterpolate(c0.g, c1.g, c2.g, c3.g, t),
                  cubicInterpolate(c0.b, c1.b, c2.b, c3.b, t),
                  cubicInterpolate(c0.a, c1.a, c2.a, c3.a, t));
}

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

    int ix0 = max(ix - 1, 0);
    int ix1 = ix;
    int ix2 = min(ix + 1, gridWidth - 1);
    int ix3 = min(ix + 2, gridWidth - 1);

    int iy0 = max(iy - 1, 0);
    int iy1 = iy;
    int iy2 = min(iy + 1, gridHeight - 1);
    int iy3 = min(iy + 2, gridHeight - 1);

    float4 col[4][4];
    for (int m = 0; m < 4; m++) {
        int xIdx[4] = {ix0, ix1, ix2, ix3};

        for (int n = 0; n < 4; n++) {
            int yIdx[4] = {iy0, iy1, iy2, iy3};
            col[m][n] = colors[yIdx[n] * gridWidth + xIdx[m]];
        }
    }

    float4 colInterp[4];
    for (int i = 0; i < 4; i++) {
        colInterp[i] = cubicInterpolateColor(col[0][i], col[1][i], col[2][i], col[3][i], tx);
    }
    
    float4 finalColor = cubicInterpolateColor(colInterp[0], colInterp[1], colInterp[2], colInterp[3], ty);
    
    // How to (and how not to) fix color banding - https://blog.frost.kiwi/GLSL-noise-and-radial-gradient/
    float noise = gradientNoise(in.position.xy);
    finalColor.rgb += (1.0 / 255.0) * noise - (0.5 / 255.0);
    
    return finalColor;
}

