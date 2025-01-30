#include <metal_stdlib>
using namespace metal;

// Vertex input structure
struct VertexIn {
    float4 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

// Vertex output structure
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Dimensions struct to pass view and image sizes
struct Dimensions {
    float viewWidth;
    float viewHeight;
    float imageWidth;
    float imageHeight;
};

// Vertex shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.uv = in.uv;
    return out;
}

// Fragment shader
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> inputTexture [[texture(0)]],
                              constant float4 &pointColor [[buffer(0)]],
                              constant float4 &lineColor [[buffer(1)]],
                              constant float &radius [[buffer(2)]],
                              constant float &strokeWidth [[buffer(3)]],
                              constant Dimensions &dims [[buffer(4)]],
                              constant float4 *points [[buffer(5)]],
                              constant int &landmarksPresent [[buffer(6)]],
                              sampler textureSampler [[sampler(0)]]) {
    // Adjust UVs to match the aspect ratio of the target image
    float2 adjustedUV = in.uv;

    // Calculate aspect ratios
    float viewAspectRatio = dims.viewWidth / dims.viewHeight;
    float imageAspectRatio = dims.imageWidth / dims.imageHeight;

    if (imageAspectRatio > viewAspectRatio) {
        adjustedUV.x = (adjustedUV.x - 0.5) *  viewAspectRatio / imageAspectRatio + 0.5;
    } else {
        adjustedUV.y = (adjustedUV.y - 0.5) *  imageAspectRatio / viewAspectRatio + 0.5;
    }

    // Sample the texture with the adjusted UVs
    float4 color = inputTexture.sample(textureSampler, adjustedUV);

    // If landmarks are present, overlay points and skeleton connections
    if (landmarksPresent != 0) {
        // Skeleton connections (hardcoded for MediaPipe hand model)
        const int connections[21][2] = {
            {0, 1}, {1, 2}, {2, 3}, {3, 4}, {0, 5}, {5, 9}, {9, 13}, {13, 17}, {0, 17},
            {5, 6}, {6, 7}, {7, 8}, {9, 10}, {10, 11}, {11, 12}, {13, 14}, {14, 15},
            {15, 16}, {17, 18}, {18, 19}, {19, 20}
        };

        // Draw skeleton lines
        for (int i = 0; i < 21; i++) {
            int startIdx = connections[i][0];
            int endIdx = connections[i][1];

            float2 startPos = points[startIdx].xy;
            float2 endPos = points[endIdx].xy;

            // Calculate line direction and distance to the line
            float2 lineDir = normalize(endPos - startPos);
            float2 pointToUV = adjustedUV - startPos;
            float projection = clamp(dot(pointToUV, lineDir), 0.0f, length(endPos - startPos));
            float2 closestPoint = startPos + lineDir * projection;
            float distToLine = length(adjustedUV - closestPoint);

            if (distToLine < strokeWidth) {
                color = lineColor; // Draw line color
            }
        }

        // Draw landmark points
        for (int i = 0; i < 21; i++) {
            float2 pointPos = points[i].xy;
            float distToPoint = distance(adjustedUV, pointPos);

            if (distToPoint < radius) {
                color = pointColor; // Draw point color
            }
        }
    }

    return color;
}
