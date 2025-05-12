import UIKit
import MetalKit

/// Custom CALayer that renders a mesh gradient using Metal
public class MeshGradientLayer: CALayer {
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?

    private var vertexBuffer: MTLBuffer?
    private var gridBuffer: MTLBuffer?
    private var colorsBuffer: MTLBuffer?
    private var textureCache: CVMetalTextureCache?
    
    private let vertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1,  1, 0, 1),
        SIMD4<Float>( 1,  1, 0, 1),
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>( 1, -1, 0, 1)
    ]

    // MARK: - Properties

    private var colors: [UIColor] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        needsDisplayOnBoundsChange = true
        contentsScale = UIScreen.main.scale
        
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(layer: Any) {
        guard let meshGradientLayer = layer as? MeshGradientLayer else {
            fatalError("Expected to init from MeshGradientLayer")
        }
        
        self.metalDevice = meshGradientLayer.metalDevice
        self.commandQueue = meshGradientLayer.commandQueue
        self.pipelineState = meshGradientLayer.pipelineState
        self.vertexBuffer = meshGradientLayer.vertexBuffer
        self.gridBuffer = meshGradientLayer.gridBuffer
        self.colorsBuffer = meshGradientLayer.colorsBuffer
        self.textureCache = meshGradientLayer.textureCache
        self.colors = meshGradientLayer.colors
        
        super.init(layer: layer)
        
        setup()
    }
    
    func traitCollectionDidChange() {
        let metalColors: [SIMD4<Float>] = colors.compactMap { convertToSIMD($0) }
        if let colorsBuffer = metalDevice?.makeBuffer(
            bytes: metalColors,
            length: MemoryLayout<SIMD4<Float>>.stride * metalColors.count
        ) {
            self.colorsBuffer = colorsBuffer
        } else {
            assertionFailure("Can't create colorsBuffer")
            self.colorsBuffer = nil
        }
    }
    
    // MARK: - Drawing
    
    public override func draw(in ctx: CGContext) {
        let width = Int(bounds.width * contentsScale)
        let height = Int(bounds.height * contentsScale)
        
        guard width > 0, height > 0 else { return }
        
        // Create a pixel buffer to share between Metal and Core Graphics
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ] as CFDictionary
        
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        guard let pixelBuffer = pixelBuffer,
              let textureCache = textureCache else { return }
        
        // Create a Metal texture from the pixel buffer
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture),
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        
        // Set up render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Create render command encoder
        guard let pipelineState, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Configure and draw
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(gridBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(colorsBuffer, offset: 0, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Draw the pixel buffer directly to Core Graphics
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        // Create a CGImage from the pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImage = bitmapContext.makeImage() else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        // Draw the CGImage to the context
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(cgImage, in: bounds)
        ctx.restoreGState()
    }
}

extension MeshGradientLayer {
    func setup() {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Can't create default device for metal")
            return
        }
        self.metalDevice = metalDevice
        
        guard let commandQueue = metalDevice.makeCommandQueue() else {
            assertionFailure("Can't create command queue from metal device")
            return
        }
        self.commandQueue = commandQueue
        
        let library: MTLLibrary
        do {
            library = try metalDevice.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            assertionFailure("Can't load metal library with error: \(error)")
            return
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
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            self.pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
            return
        }
        
        let vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD4<Float>>.stride * 4
        )
        guard let vertexBuffer else {
            assertionFailure("Can't create vertexBuffer")
            return
        }
        self.vertexBuffer = vertexBuffer
    }

    func configure(
        width: Int,
        height: Int,
        colors: [UIColor]
    ) {
        guard (width * height) == colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return
        }
        
        var grid = MeshGradientGrid(width: Int32(width), height: Int32(height))

        if let gridBuffer = metalDevice?.makeBuffer(
            bytes: &grid,
            length: MemoryLayout<MeshGradientGrid>.stride
        ) {
            self.gridBuffer = gridBuffer
        } else {
            assertionFailure("Can't create gridBuffer")
            self.gridBuffer = nil
        }
        
        let metalColors: [SIMD4<Float>] = colors.compactMap { convertToSIMD($0) }
        
        if let colorsBuffer = metalDevice?.makeBuffer(
            bytes: metalColors,
            length: MemoryLayout<SIMD4<Float>>.stride * metalColors.count
        ) {
            self.colorsBuffer = colorsBuffer
            self.colors = colors
        } else {
            assertionFailure("Can't create colorsBuffer")
            self.colorsBuffer = nil
            self.colors = []
        }

        if let metalDevice = metalDevice {
            // Create texture cache
            var textureCache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
            self.textureCache = textureCache
        } else {
            assertionFailure("Can't create textureCache")
            self.textureCache = nil
        }
    }
}

private extension MeshGradientLayer {
    func convertToSIMD(_ color: UIColor) -> SIMD4<Float>? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
