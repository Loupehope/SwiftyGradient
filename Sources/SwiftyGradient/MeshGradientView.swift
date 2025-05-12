import UIKit
import MetalKit

public class SwiftyGradientView: UIView {
    private var gradientLayer: MeshGradientLayer? {
        layer as? MeshGradientLayer
    }

    public override class var layerClass: AnyClass {
        MeshGradientLayer.self
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        let meshGradientLayer: MeshGradientLayer? = layer as? MeshGradientLayer
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            meshGradientLayer?.traitCollectionDidChange()
            meshGradientLayer?.setNeedsDisplay()
        }
    }
}

extension SwiftyGradientView {
    public func configure(
        width: Int,
        height: Int,
        colors: [UIColor]
    ){
        gradientLayer?.configure(width: width, height: height, colors: colors)
        gradientLayer?.setNeedsDisplay()
    }
}
