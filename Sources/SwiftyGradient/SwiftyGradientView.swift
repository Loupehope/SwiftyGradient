import UIKit
import MetalKit

public class SwiftyGradientView: UIView {
    private let metalView: MTKView
    private let metalManager: ManagesSwiftyMetal & MTKViewDelegate

    // MARK: - Initialization

    public init(
        metalDevice: (any MTLDevice)? = MTLCreateSystemDefaultDevice(),
        drawableSize: CGSize = CGSize(width: 50, height: 50)
    ) {
        if let metalDevice {
            metalView = MTKView(frame: .zero, device: metalDevice)
        } else {
            assertionFailure("Can't create command queue from metal device")
            metalView = MTKView(frame: .zero, device: nil)
        }
        
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize
        metalView.isPaused = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .invalid
        metalView.enableSetNeedsDisplay = true
        
        metalManager = SwiftyMetalManager(colorPixelFormat: metalView.colorPixelFormat, metalDevice: metalDevice)
        metalView.delegate = metalManager

        super.init(frame: .zero)
        
        addSubview(metalView)
        
        metalView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            metalManager.traitCollectionDidChange()
            metalView.setNeedsDisplay()
        }
    }
}

extension SwiftyGradientView {
    public struct SwiftyGradientViewModel {
        public let width: Int
        public let height: Int
        public let colors: [UIColor]
        
        public init(width: Int, height: Int, colors: [UIColor]) {
            self.width = width
            self.height = height
            self.colors = colors
        }
    }
    
    public func configure(_ viewModel: SwiftyGradientViewModel) {
        metalManager.updateBuffers(width: viewModel.width, height: viewModel.height, colors: viewModel.colors)
        metalView.setNeedsDisplay()
    }
}
