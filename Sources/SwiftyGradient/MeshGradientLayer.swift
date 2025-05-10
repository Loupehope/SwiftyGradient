//
//  MeshGradientLayer.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit

/// A CALayer subclass that renders a mesh gradient with bezier points
final class MeshGradientLayer: CALayer {
    /// Array of mesh points that define the gradient
    var meshPoints: [UIColor] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    /// The quality of the gradient render (higher = smoother but more CPU intensive)
    /// Default value provides good balance between quality and performance
    var meshRenderQuality: CGFloat = 0.5 {
        didSet {
            setNeedsDisplay()
        }
    }

    var meshWidth: Int = .zero {
        didSet {
            setNeedsDisplay()
        }
    }

    var meshHeight: Int = .zero {
        didSet {
            setNeedsDisplay()
        }
    }

    var meshColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB() {
        didSet {
            setNeedsDisplay()
        }
    }

    private var cachedImage: CGImage?
    private let colorCalculator = MeshGradientColorCalculator()

    // Enable content rendering
    override init() {
        super.init()

        needsDisplayOnBoundsChange = true
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let meshLayer = layer as? MeshGradientLayer {
            self.meshPoints = meshLayer.meshPoints
            self.meshRenderQuality = meshLayer.meshRenderQuality
            self.meshWidth = meshLayer.meshWidth
            self.meshHeight = meshLayer.meshHeight
            self.meshColorSpace = meshLayer.meshColorSpace
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        needsDisplayOnBoundsChange = true
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)

        guard !meshPoints.isEmpty else { return }

        let scale = UIScreen.main.scale
        let contextWidth = Int(bounds.width * scale)
        let contextHeight = Int(bounds.height * scale)

        // Create a bitmap context to render the gradient
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let bitmapContext = CGContext(
            data: nil,
            width: contextWidth,
            height: contextHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: meshColorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }

        // Scale the context to match our quality setting
        bitmapContext.scaleBy(x: scale, y: scale)

        // Render the mesh gradient into the bitmap context
        renderMeshGradient(in: bitmapContext, size: bounds.size)

        guard let image = bitmapContext.makeImage() else { return }

        _ = CIContext(cgContext: bitmapContext)

        // Draw image
        ctx.saveGState()
        ctx.draw(image, in: bounds)
        ctx.restoreGState()
    }

    /// Render the mesh gradient into the provided context
    private func renderMeshGradient(in ctx: CGContext, size: CGSize) {
        let width = size.width
        let height = size.height

        // Calculate the grid size for initial rendering
        let colorCalculator = MeshGradientColorCalculator()
        let gridSize = max(Int(min(width, height) * meshRenderQuality * 0.5), 10)
        let cellWidth = width / CGFloat(gridSize)
        let cellHeight = height / CGFloat(gridSize)

        // Draw each cell of the grid with calculated color
        for x in 0..<gridSize {
            for y in 0..<gridSize {
                let rect = CGRect(
                    x: CGFloat(x) * cellWidth,
                    y: CGFloat(y) * cellHeight,
                    width: cellWidth + 1, // Add 1 to avoid gaps
                    height: cellHeight + 1
                )

                // Calculate normalized position of the cell center
                let normalizedX = (CGFloat(x) * cellWidth + cellWidth / 2) / width
                let normalizedY = (CGFloat(y) * cellHeight + cellHeight / 2) / height
                let position = CGPoint(x: normalizedX, y: normalizedY)

                // Get the color for this position
                let color = colorCalculator.color(at: position, meshPoints: meshPoints, rows: meshHeight, columns: meshWidth)

                // Fill the cell with the calculated color
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
            }
        }
    }
}
