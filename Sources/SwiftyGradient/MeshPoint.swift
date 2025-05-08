//
//  MeshPoint.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit

/// A mesh gradient point with color and position
struct MeshPoint {
    /// The color at this point
    let color: UIColor
    /// The position of this point (normalized coordinates 0-1)
    let position: CGPoint
}
