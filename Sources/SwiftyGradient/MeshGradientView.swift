//
//  MeshGradientView.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit

/// UIView wrapper for MeshGradientLayer to make it easier to use in UIKit
public class MeshGradientView: UIView {
    // Use MeshGradientLayer as the layer class
    public override class var layerClass: AnyClass {
        MeshGradientLayer.self
    }

    // MARK: - Initialization

    public init?(
        width: Int,
        height: Int,
        bezierPoints: [CGPoint],
        colors: [UIColor],
        colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    ) {
        guard (width * height) == bezierPoints.count, (width * height) == colors.count else {
            return nil
        }

        super.init(frame: .zero)

        let meshGradientLayer: MeshGradientLayer? = layer as? MeshGradientLayer

        meshGradientLayer?.meshColorSpace = colorSpace
        meshGradientLayer?.meshWidth = width
        meshGradientLayer?.meshHeight = height
        meshGradientLayer?.meshPoints = zip(colors, bezierPoints).map { MeshPoint(color: $0, position: $1) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
