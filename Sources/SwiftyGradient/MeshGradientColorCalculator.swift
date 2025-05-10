//
//  MeshGradientColorCalculator.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit

/// A class that handles mesh gradient color calculations using bicubic interpolation
final class MeshGradientColorCalculator {
    
    /// Calculates a color at a specified point using bicubic interpolation over a mesh of points
    /// - Parameters:
    ///   - point: The query position in normalized [0…1] coordinates
    ///   - meshPoints: Array of mesh points with their colors and positions
    ///   - rows: Number of rows in the mesh
    ///   - columns: Number of columns in the mesh
    /// - Returns: The interpolated UIColor at the specified point
    func color(at point: CGPoint, meshPoints: [MeshPoint], rows: Int, columns: Int) -> UIColor {
        // Validate the mesh configuration
        guard isValidMesh(rows: rows, columns: columns, pointsCount: meshPoints.count) else {
            return UIColor.red
        }
        
        // Ensure the point is within valid range [0,1]
        let normalizedPoint = normalizePoint(point)
        
        // Get the grid cell containing the point and the fractional position within that cell
        let (gridCell, fractionalPosition) = calculateGridPosition(point: normalizedPoint,
                                                                  rows: rows,
                                                                  columns: columns)
        
        // Calculate cubic spline weights for x and y directions
        let xWeights = calculateCubicWeights(t: fractionalPosition.x)
        let yWeights = calculateCubicWeights(t: fractionalPosition.y)
        
        // Calculate the interpolated color
        return interpolateColor(gridCell: gridCell,
                               xWeights: xWeights,
                               yWeights: yWeights,
                               meshPoints: meshPoints,
                               rows: rows,
                               columns: columns)
    }
    
    // MARK: - Private Helper Methods
    
    /// Validates that the mesh configuration meets the requirements
    private func isValidMesh(rows: Int, columns: Int, pointsCount: Int) -> Bool {
        guard rows >= 2 && columns >= 2 && pointsCount == rows * columns else {
            print("Invalid mesh configuration: requires at least 2x2 grid and rows*columns must equal meshPoints.count")
            return false
        }
        return true
    }
    
    /// Ensures the point is clamped to the valid range [0,1]
    private func normalizePoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: max(0, min(1, point.x)),
            y: max(0, min(1, point.y))
        )
    }
    
    /// Calculates the grid cell coordinates and fractional position within that cell
    private func calculateGridPosition(point: CGPoint, rows: Int, columns: Int) -> (cell: (x: Int, y: Int), fraction: (x: Float, y: Float)) {
        // Convert normalized coordinates to grid coordinates
        let gridX = point.x * Double(columns - 1)
        let gridY = point.y * Double(rows - 1)
        
        // Get base grid cell
        let x0 = Int(floor(gridX))
        let y0 = Int(floor(gridY))
        
        // Calculate fractional position within cell
        let tx = Float(gridX - Double(x0))
        let ty = Float(gridY - Double(y0))
        
        return ((x0, y0), (tx, ty))
    }
    
    /// Calculates the four cubic Catmull-Rom spline basis function weights for a given parameter t
    private func calculateCubicWeights(t: Float) -> [Float] {
        let t2 = t * t
        let t3 = t2 * t
        
        // Catmull-Rom spline basis functions
        let w0 = -0.5 * t3 + t2 - 0.5 * t      // h₀(t) for P_{i-1}
        let w1 = 1.5 * t3 - 2.5 * t2 + 1.0     // h₁(t) for P_i
        let w2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t // h₂(t) for P_{i+1}
        let w3 = 0.5 * t3 - 0.5 * t2           // h₃(t) for P_{i+2}
        
        return [w0, w1, w2, w3]
    }
    
    /// Performs the bicubic interpolation to calculate the color
    private func interpolateColor(gridCell: (x: Int, y: Int),
                                 xWeights: [Float],
                                 yWeights: [Float],
                                 meshPoints: [MeshPoint],
                                 rows: Int,
                                 columns: Int) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        // Loop through 4x4 grid of control points centered around our cell
        for j in 0..<4 {
            // Get y-index with clamping to valid range
            let yIdx = max(0, min(rows - 1, gridCell.y - 1 + j))
            let wy = yWeights[j]
            
            for i in 0..<4 {
                // Get x-index with clamping to valid range
                let xIdx = max(0, min(columns - 1, gridCell.x - 1 + i))
                let wx = xWeights[i]
                
                // Get the mesh point color
                let index = yIdx * columns + xIdx
                let color = meshPoints[index].color
                
                // Extract color components
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
                // Apply weight (product of basis functions) to each component
                let weight = CGFloat(wx * wy)
                
                // Accumulate weighted color contributions
                r += red * weight
                g += green * weight
                b += blue * weight
                a += alpha * weight
            }
        }
        
        // Clamp color components to valid range
        return UIColor(
            red: clamp(r, min: 0, max: 1),
            green: clamp(g, min: 0, max: 1),
            blue: clamp(b, min: 0, max: 1),
            alpha: clamp(a, min: 0, max: 1)
        )
    }
    
    /// Clamps a value between a minimum and maximum
    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        return max(minValue, min(maxValue, value))
    }
}
