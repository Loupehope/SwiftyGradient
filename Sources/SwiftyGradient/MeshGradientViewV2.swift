//
//  MeshGradientViewV2.swift
//  SwiftyGradient
//
//  Created by Pavel Murzinov on 12.05.2025.
//


import UIKit
import MetalKit

/// UIView wrapper for MeshGradientLayer to make it easier to use in UIKit
public class MeshGradientViewV2: UIView {

    private let metalView: MTKView
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]
    private var colors: [UIColor] = []
    private var metalColors: [SIMD4<Float>] = []
    private var grid: MeshGradientGrid = MeshGradientGrid(width: 1, height: 1)

    // MARK: - Initialization

    public init?(
        drawableSize: CGSize = CGSize(width: 10, height: 10)
    ) {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Can't create default device for metal")
            return nil
        }

        metalView = MTKView(frame: .zero, device: metalDevice)
        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize
        metalView.presentsWithTransaction = true
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .invalid // Avoid unless needed

        guard let commandQueue = metalDevice.makeCommandQueue() else {
            assertionFailure("Can't create command queue from metal device")
            return nil
        }
        self.commandQueue = commandQueue

        let library: MTLLibrary
        do {
            library = try metalDevice.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            assertionFailure("Can't load metal library with error: \(error)")
            return nil
        }
        let vertexFunction = library.makeFunction(name: "meshGradientVertex")
        let fragmentFunction = library.makeFunction(name: "meshGradientFragment")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stepRate = 1

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            self.pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
            return nil
        }

        super.init(frame: .zero)

        metalView.delegate = self
        addSubview(metalView)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection), !colors.isEmpty else { return }
        metalColors = colors.compactMap(convertToSIMD4FloatFromUIColor)
        metalView.setNeedsDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(
        width: Int,
        height: Int,
        colors: [UIColor]
    ) {
        guard (width * height) == colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return
        }

        self.grid = MeshGradientGrid(width: Int32(width), height: Int32(height))
        self.colors = colors
        self.metalColors = colors.compactMap(convertToSIMD4FloatFromUIColor)
        self.metalView.setNeedsDisplay()
    }
}

extension MeshGradientViewV2: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)

        encoder?.setRenderPipelineState(pipelineState)
        encoder?.setVertexBytes(vertices, length: MemoryLayout<SIMD4<Float>>.stride * vertices.count, index: 0)
        encoder?.setFragmentBytes(&grid, length: MemoryLayout<MeshGradientGrid>.stride, index: 0)
        encoder?.setFragmentBytes(metalColors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count, index: 1)
        encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        encoder?.endEncoding()

        commandBuffer?.commit()
        commandBuffer?.waitUntilScheduled()
        
        view.currentDrawable?.present()
    }
}

private extension MeshGradientViewV2 {
    func convertToSIMD4FloatFromUIColor(_ color: UIColor) -> SIMD4<Float>? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
