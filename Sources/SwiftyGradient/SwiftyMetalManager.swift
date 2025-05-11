import UIKit
import MetalKit

struct SwiftyMetalGrid {
    let width: Int32
    let height: Int32
}

protocol ManagesSwiftyMetal {
    func updateBuffers(width: Int, height: Int, colors: [UIColor])
}

final class SwiftyMetalManager: NSObject {
    private let metalDevice: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private let vertexBuffer: MTLBuffer?

    private var gridBuffer: MTLBuffer?
    private var colorsBuffer: MTLBuffer?
    
    private let mutex = NSLock()
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]
    
    init(colorPixelFormat: MTLPixelFormat, metalDevice: (any MTLDevice)?) {
        if let metalDevice {
            self.metalDevice = metalDevice
        } else {
            assertionFailure("Can't create command queue from metal device")
            self.metalDevice = nil
        }
        
        if let commandQueue = metalDevice?.makeCommandQueue() {
            self.commandQueue = commandQueue
        } else {
            assertionFailure("Can't create command queue from metal device")
            commandQueue = nil
        }
        
        let library: MTLLibrary?
        do {
            library = try metalDevice?.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            assertionFailure("Can't load metal library with error: \(error)")
            library = nil
        }
        
        if let vertexBuffer = metalDevice?.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD4<Float>>.stride * vertices.count) {
            self.vertexBuffer = vertexBuffer
        } else {
            assertionFailure("Can't create vertexBuffer")
            self.vertexBuffer = nil
        }

        let vertexFunction = library?.makeFunction(name: "swiftyGradientVertex")
        let fragmentFunction = library?.makeFunction(name: "swiftyGradientFragment")

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
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipelineState = try metalDevice?.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state with error: \(error)")
            pipelineState = nil
        }

        super.init()
    }
}

extension SwiftyMetalManager: ManagesSwiftyMetal {
    func updateBuffers(width: Int, height: Int, colors: [UIColor]) {
        mutex.lock()
        defer { mutex.unlock() }

        guard (width * height) == colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return
        }
        
        var grid = SwiftyMetalGrid(width: Int32(width), height: Int32(height))
        
        if let gridBuffer = metalDevice?.makeBuffer(bytes: &grid, length: MemoryLayout<SwiftyMetalGrid>.stride) {
            self.gridBuffer = gridBuffer
        } else {
            assertionFailure("Can't create gridBuffer")
            self.gridBuffer = nil
        }

        let colors: [SIMD4<Float>] = colors.compactMap { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        
        if let colorsBuffer = metalDevice?.makeBuffer(bytes: colors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count) {
            self.colorsBuffer = colorsBuffer
        } else {
            assertionFailure("Can't create colorsBuffer")
            self.colorsBuffer = nil
        }
    }
}

extension SwiftyMetalManager: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        mutex.lock()

        guard let pipelineState,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
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
