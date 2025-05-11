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
            metalManager = SwiftyMetalManager(colorPixelFormat: metalView.colorPixelFormat, metalDevice: metalDevice)
        } else {
            assertionFailure("Can't create command queue from metal device")
            metalView = MTKView(frame: .zero, device: nil)
            metalManager = SwiftyMetalManager(colorPixelFormat: metalView.colorPixelFormat, metalDevice: nil)
        }

        super.init(frame: .zero)
        
        addSubview(metalView)
        
        metalView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize
        metalView.delegate = metalManager
        metalView.isPaused = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .invalid
        metalView.enableSetNeedsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
