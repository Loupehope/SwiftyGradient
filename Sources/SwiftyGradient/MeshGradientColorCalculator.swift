//
//  MeshGradientColorCalculator.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit

final class MeshGradientColorCalculator {
    /// Bicubic‐interpolate a color at normalized (u,v) over this linear MeshPoint array.
    ///
    /// - Parameters:
    ///   - point: The query position in normalized [0…1] coordinates.
    ///   - columns: Number of columns in the mesh. Must divide `self.count` evenly.
    /// - Returns: The interpolated UIColor.
    func color(at point: CGPoint, meshPoints: [MeshPoint], rows: Int, columns: Int) -> UIColor {
        // Clamp input point to valid range
        let u = max(0, min(1, point.x))
        let v = max(0, min(1, point.y))

        // Calculate grid coordinates
        let gridX = u * Double(columns - 1)
        let gridY = v * Double(rows - 1)

        // Get base grid cell
        let x0 = Int(floor(gridX))
        let y0 = Int(floor(gridY))

        // Calculate fractional position within cell (t parameters)
        let tx = Float(gridX - Double(x0))
        let ty = Float(gridY - Double(y0))

        // Pre-compute cubic spline basis functions
        // These are the Catmull-Rom spline basis functions
        // Source: "Cubic Convolution Interpolation for Digital Image Processing" by R. Keys (1981)
        // and "Computer Graphics: Principles and Practice" by Foley, van Dam, Feiner, and Hughes

        // For x direction
        let tx2 = tx * tx
        let tx3 = tx2 * tx

        // h_0(t) = -0.5t³ + t² - 0.5t     (coefficient for P_{i-1})
        let wx0 = -0.5 * tx3 + tx2 - 0.5 * tx

        // h_1(t) = 1.5t³ - 2.5t² + 1      (coefficient for P_i)
        let wx1 = 1.5 * tx3 - 2.5 * tx2 + 1.0

        // h_2(t) = -1.5t³ + 2t² + 0.5t    (coefficient for P_{i+1})
        let wx2 = -1.5 * tx3 + 2.0 * tx2 + 0.5 * tx

        // h_3(t) = 0.5t³ - 0.5t²          (coefficient for P_{i+2})
        let wx3 = 0.5 * tx3 - 0.5 * tx2

        // For y direction - same formulas as x, but with ty
        let ty2 = ty * ty
        let ty3 = ty2 * ty
        let wy0 = -0.5 * ty3 + ty2 - 0.5 * ty  // h_0(t_y)
        let wy1 = 1.5 * ty3 - 2.5 * ty2 + 1.0  // h_1(t_y)
        let wy2 = -1.5 * ty3 + 2.0 * ty2 + 0.5 * ty  // h_2(t_y)
        let wy3 = 0.5 * ty3 - 0.5 * ty2  // h_3(t_y)

        // Create reusable component variables for color extraction
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0

        // Variables to accumulate weighted color contributions
        // The bicubic interpolation formula is:
        // f(x,y) = ∑_{j=0}^3 ∑_{i=0}^3 f(i,j) * h_i(t_x) * h_j(t_y)
        // where f(i,j) are the control points, h_i and h_j are the basis functions
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        // Loop through 4x4 grid of control points centered around (x0,y0)
        for j in 0..<4 {
            // Compute y index with clamping to valid range
            let yIdx = max(0, min(rows - 1, y0 - 1 + j))

            // Select weight for this y position
            let wy = j == 0 ? wy0 : (j == 1 ? wy1 : (j == 2 ? wy2 : wy3))

            for i in 0..<4 {
                // Compute x index with clamping to valid range
                let xIdx = max(0, min(columns - 1, x0 - 1 + i))

                // Select weight for this x position
                let wx = i == 0 ? wx0 : (i == 1 ? wx1 : (i == 2 ? wx2 : wx3))

                // Get color at this mesh point
                let index = yIdx * columns + xIdx
                let color = meshPoints[index].color

                // Extract color components
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                // Calculate the final weight for this control point
                // This is the product of basis functions: h_i(t_x) * h_j(t_y)
                let weight = CGFloat(wx * wy)

                // Apply weight to each color component and accumulate
                r += red * weight
                g += green * weight
                b += blue * weight
                a += alpha * weight
            }
        }

        // Clamp final color components to [0,1] range
        // This is necessary as the Catmull-Rom interpolant can slightly exceed bounds
        r = max(0, min(1, r))
        g = max(0, min(1, g))
        b = max(0, min(1, b))
        a = max(0, min(1, a))

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
