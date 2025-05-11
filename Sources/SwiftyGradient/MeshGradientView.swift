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
    private let vertexBuffer: MTLBuffer
    private let gridBuffer: MTLBuffer
    private let colorsBuffer: MTLBuffer
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]

    // MARK: - Initialization

    public init?(
        width: Int,
        height: Int,
        colors: [UIColor],
        drawableSize: CGSize = CGSize(width: 200, height: 200)
    ) {
        guard (width * height) == colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return nil
        }

        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Can't create default device for metal")
            return nil
        }

        metalView = MTKView(frame: .zero, device: metalDevice)
        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize

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

        let vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD4<Float>>.stride * vertices.count
        )
        guard let vertexBuffer else {
            assertionFailure("Can't create vertexBuffer")
            return nil
        }
        self.vertexBuffer = vertexBuffer

        var grid = MeshGradientGrid(width: Int32(width), height: Int32(height))
        let gridBuffer = metalDevice.makeBuffer(
            bytes: &grid,
            length: MemoryLayout<MeshGradientGrid>.stride
        )
        guard let gridBuffer else {
            assertionFailure("Can't create gridBuffer")
            return nil
        }
        self.gridBuffer = gridBuffer

        let colors: [SIMD4<Float>] = colors.compactMap { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        let colorsBuffer = metalDevice.makeBuffer(
            bytes: colors,
            length: MemoryLayout<SIMD4<Float>>.stride * colors.count
        )
        guard let colorsBuffer else {
            assertionFailure("Can't create colorsBuffer")
            return nil
        }
        self.colorsBuffer = colorsBuffer

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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MeshGradientView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor
        else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)

        encoder?.setRenderPipelineState(pipelineState)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder?.setFragmentBuffer(gridBuffer, offset: 0, index: 0)
        encoder?.setFragmentBuffer(colorsBuffer, offset: 0, index: 1)
        encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        encoder?.endEncoding()

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        metalView.isPaused = true
    }
}
