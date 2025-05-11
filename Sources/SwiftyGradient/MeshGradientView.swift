//
//  MeshGradientView.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit
import MetalKit

/// UIView wrapper for MeshGradientLayer to make it easier to use in UIKit
public class MeshGradientView: UIView {
    private let metalView: MTKView
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    private var vertexBuffer: MTLBuffer?
    private var gridBuffer: MTLBuffer?
    private var colorsBuffer: MTLBuffer?
    
    private let mutex = NSLock()
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]

    // MARK: - Initialization

    public init?(
        metalDevice: (any MTLDevice)? = MTLCreateSystemDefaultDevice(),
        drawableSize: CGSize = CGSize(width: 50, height: 50)
    ) {
        guard let metalDevice = metalDevice ?? MTLCreateSystemDefaultDevice() else {
            assertionFailure("Can't create default device for metal")
            return nil
        }

        metalView = MTKView(frame: .zero, device: metalDevice)

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
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
            return nil
        }

        super.init(frame: .zero)

        metalView.delegate = self
        metalView.isPaused = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .invalid
        metalView.enableSetNeedsDisplay = true
        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize

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
}

extension MeshGradientView {
    public struct MeshGradientViewModel {
        public let  width: Int
        public let height: Int
        public let colors: [UIColor]
        
        public init(width: Int, height: Int, colors: [UIColor]) {
            self.width = width
            self.height = height
            self.colors = colors
        }
    }
    
    public func configure(_ viewModel: MeshGradientViewModel) {
        mutex.lock()
        defer { mutex.unlock() }

        guard (viewModel.width * viewModel.height) == viewModel.colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return
        }
        
        guard let vertexBuffer = metalView.device?.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD4<Float>>.stride * vertices.count
        ) else {
            assertionFailure("Can't create vertexBuffer")
            return
        }

        self.vertexBuffer = vertexBuffer
        
        var grid = MeshGradientGrid(width: Int32(viewModel.width), height: Int32(viewModel.height))
        
        guard let gridBuffer = metalView.device?.makeBuffer(
            bytes: &grid,
            length: MemoryLayout<MeshGradientGrid>.stride
        ) else {
            assertionFailure("Can't create gridBuffer")
            return
        }
        self.gridBuffer = gridBuffer

        let colors: [SIMD4<Float>] = viewModel.colors.compactMap { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        
        guard let colorsBuffer = metalView.device?.makeBuffer(
            bytes: colors,
            length: MemoryLayout<SIMD4<Float>>.stride * colors.count
        ) else {
            assertionFailure("Can't create colorsBuffer")
            return
        }

        self.colorsBuffer = colorsBuffer
        
        metalView.setNeedsDisplay()
    }
}

extension MeshGradientView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    public func draw(in view: MTKView) {
        mutex.lock()

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            mutex.unlock()
            return
        }

        commandBuffer.addCompletedHandler { _ in
            self.mutex.unlock()
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(gridBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(colorsBuffer, offset: 0, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
