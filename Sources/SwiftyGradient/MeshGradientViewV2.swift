//
//  MeshGradientViewV2.swift
//  SwiftyGradient
//
//  Created by Pavel Murzinov on 12.05.2025.
//


import UIKit
import MetalKit

/// UIView wrapper for MeshGradientLayer to make it easier to use in UIKit
@available(iOS 26, *)
public class MeshGradientViewV2: UIView {
    private let metalView: MTKView
    private let commandQueue: MTL4CommandQueue
    private let commandBuffer: MTL4CommandBuffer
    private let compiler: MTL4Compiler
    private let pipelineState: MTLRenderPipelineState
    private let vertexDataBuffer: MTLBuffer
    private let vertexArgumentTable: MTL4ArgumentTable
    private let fragmentArgumentTable: MTL4ArgumentTable
    private let commandAllocator: MTL4CommandAllocator
    private var gridDataBuffer: MTLBuffer?
    private var colorsDataBuffer: MTLBuffer?
    private let metalDevice: MTLDevice
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]
    
    private var frameNumber = 0
    private var colors: [UIColor] = []
    private var metalColors: [SIMD4<Float>] = []
    private var grid: MeshGradientGrid = MeshGradientGrid(width: 1, height: 1)

    // MARK: - Initialization

    public init?(
        drawableSize: CGSize = CGSize(width: 256, height: 256)
    ) {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Can't create default device for metal")
            return nil
        }
        
        self.metalDevice = metalDevice

        metalView = MTKView(frame: .zero, device: metalDevice)
        metalView.autoResizeDrawable = false
        metalView.drawableSize = drawableSize
        metalView.presentsWithTransaction = true
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .invalid // Avoid unless needed

        guard let commandQueue = metalDevice.makeMTL4CommandQueue() else {
            assertionFailure("Can't create command queue from metal device")
            return nil
        }
        self.commandQueue = commandQueue
        
        guard let commandBuffer = metalDevice.makeCommandBuffer() else {
            assertionFailure("Can't create command buffer from metal device")
            return nil
        }
        self.commandBuffer = commandBuffer

        let library: MTLLibrary
        do {
            library = try metalDevice.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            assertionFailure("Can't load metal library with error: \(error)")
            return nil
        }
        
        let cf = MTL4CompilerDescriptor()
        guard let compiler = try? metalDevice.makeCompiler(descriptor: cf) else {
            assertionFailure("Can't create command buffer from metal device")
            return nil
        }
        self.compiler = compiler
        
        vertexDataBuffer = metalDevice.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD4<Float>>.stride * vertices.count)!
        
        let desc = MTL4ArgumentTableDescriptor()
        desc.maxBufferBindCount = 1
        vertexArgumentTable = try! metalDevice.makeArgumentTable(descriptor: desc)
        vertexArgumentTable.setAddress(vertexDataBuffer.gpuAddress, index: 0)
        
        let desc1 = MTL4ArgumentTableDescriptor()
        desc1.maxBufferBindCount = 2
        fragmentArgumentTable = try! metalDevice.makeArgumentTable(descriptor: desc1)
                
        let vertexFunction = MTL4LibraryFunctionDescriptor()
        vertexFunction.library = library
        vertexFunction.name = "meshGradientVertex"

        let fragmentFunction = MTL4LibraryFunctionDescriptor()
        fragmentFunction.library = library
        fragmentFunction.name = "meshGradientFragment"
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stepRate = 1

        let pipelineDescriptor = MTL4RenderPipelineDescriptor()
        pipelineDescriptor.label = "Hello!"
        pipelineDescriptor.vertexFunctionDescriptor = vertexFunction
        pipelineDescriptor.fragmentFunctionDescriptor = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat

        do {
            self.pipelineState = try compiler.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
            return nil
        }

        self.commandAllocator = metalDevice.makeCommandAllocator()!

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
        
        colorsDataBuffer = metalDevice.makeBuffer(bytes: metalColors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count)
        
        fragmentArgumentTable.setAddress(colorsDataBuffer!.gpuAddress, index: 1)

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
        
        gridDataBuffer = metalDevice.makeBuffer(bytes: &grid, length: MemoryLayout<MeshGradientGrid>.stride)
        colorsDataBuffer = metalDevice.makeBuffer(bytes: metalColors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count)
        
        fragmentArgumentTable.setAddress(gridDataBuffer!.gpuAddress, index: 0)
        fragmentArgumentTable.setAddress(colorsDataBuffer!.gpuAddress, index: 1)

        self.metalView.setNeedsDisplay()
    }
}

@available(iOS 26, *)
extension MeshGradientViewV2: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        autoreleasepool {
            guard let descriptor = view.currentMTL4RenderPassDescriptor, let drawable = view.currentDrawable else {
                return
            }
            
            /// The array index for this frame's resources.
            commandAllocator.reset()
            commandBuffer.beginCommandBuffer(allocator: commandAllocator)
            let encoder: MTL4RenderCommandEncoder? = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            
            encoder?.barrier(
                afterQueueStages: .dispatch,
                beforeStages: .vertex,
                visibilityOptions: .device
            )
            
            encoder?.setRenderPipelineState(pipelineState)
            encoder?.setArgumentTable(vertexArgumentTable, stages: .vertex)
            encoder?.setArgumentTable(fragmentArgumentTable, stages: .fragment)
            encoder?.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
            
            encoder?.endEncoding()
            
            commandBuffer.endCommandBuffer()
            commandQueue.waitForDrawable(drawable)
            commandQueue.commit([commandBuffer])
            commandQueue.signalDrawable(drawable)
            
            drawable.present()
        }
    }
}

@available(iOS 26, *)
private extension MeshGradientViewV2 {
    func convertToSIMD4FloatFromUIColor(_ color: UIColor) -> SIMD4<Float>? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
