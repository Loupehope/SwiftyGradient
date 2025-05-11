#include <metal_stdlib>
using namespace metal;

struct SwiftyGradientVertexIn {
    float4 position [[attribute(0)]];
};

struct SwiftyGradientVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct SwiftyGradientGrid {
    int width;
    int height;
};

vertex SwiftyGradientVertexOut swiftyGradientVertex(SwiftyGradientVertexIn in [[stage_in]]) {
    SwiftyGradientVertexOut out;
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

fragment float4 swiftyGradientFragment(SwiftyGradientVertexOut in [[stage_in]],
                                     constant SwiftyGradientGrid *grid [[buffer(0)]],
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
        for (int n = 0; n < 4; n++) {
            int sampleX = (m == 0) ? ix0 : (m == 1) ? ix1 : (m == 2) ? ix2 : ix3;
            int sampleY = (n == 0) ? iy0 : (n == 1) ? iy1 : (n == 2) ? iy2 : iy3;
            col[m][n] = colors[sampleY * gridWidth + sampleX];
        }
    }

    float4 colInterp[4];
    for (int i = 0; i < 4; i++) {
        colInterp[i] = cubicInterpolateColor(col[0][i], col[1][i], col[2][i], col[3][i], tx);
    }

    return cubicInterpolateColor(colInterp[0], colInterp[1], colInterp[2], colInterp[3], ty);
}
