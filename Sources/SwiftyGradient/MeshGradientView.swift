//
//  MeshGradientLayer.swift
//  MeshGradients
//
//  Created by Vlad Suhomlinov on 08/05/2025.
//

import UIKit
import MetalKit
import CoreImage.CIFilterBuiltins

public class MeshGradientView: UIView {
    // Use MeshGradientLayer as the layer class
    public override class var layerClass: AnyClass {
        MeshGradientLayer.self
    }
    
    public init?(
        width: Int,
        height: Int,
        colors: [UIColor]
    ){
        guard (width * height) == colors.count else {
            assertionFailure("Expected to see colors count equal to `width * height`!")
            return nil
        }
        
        super.init(frame: .zero)
        
        let meshGradientLayer: MeshGradientLayer? = layer as? MeshGradientLayer
        meshGradientLayer?.configure(width: width, height: height, colors: colors)
        meshGradientLayer?.setNeedsDisplay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

/// Custom CALayer that renders a mesh gradient using Metal
public class MeshGradientLayer: CALayer {
    // Metal resources
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
    private var cachedImage: CGImage?
    private var cachedSize: CGSize = .zero
    // MARK: - Properties
    
    private var width: Int?
    private var height: Int?
    private var colors: [UIColor] = []
    
    // MARK: - Initialization
    
    // Enable content rendering
    override init() {
        super.init()
        
        needsDisplayOnBoundsChange = true
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
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            self.pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
            return
        }
        
        let vertexBuffer = metalDevice.makeBuffer(
            bytes: [
                SIMD4<Float>(-1,  1, 0, 1),
                SIMD4<Float>( 1,  1, 0, 1),
                SIMD4<Float>(-1, -1, 0, 1),
                SIMD4<Float>( 1, -1, 0, 1)
            ],
            length: MemoryLayout<SIMD4<Float>>.stride * 4
        )
        guard let vertexBuffer else {
            assertionFailure("Can't create vertexBuffer")
            return
        }
        self.vertexBuffer = vertexBuffer
        
        var grid = MeshGradientGrid(width: Int32(width), height: Int32(height))
        let gridBuffer = metalDevice.makeBuffer(
            bytes: &grid,
            length: MemoryLayout<MeshGradientGrid>.stride
        )
        guard let gridBuffer else {
            assertionFailure("Can't create gridBuffer")
            return
        }
        self.gridBuffer = gridBuffer
        
        let metalColors: [SIMD4<Float>] = colors.compactMap { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        
        let colorsBuffer = metalDevice.makeBuffer(
            bytes: metalColors,
            length: MemoryLayout<SIMD4<Float>>.stride * metalColors.count
        )
        guard let colorsBuffer else {
            assertionFailure("Can't create colorsBuffer")
            return
        }
        self.colorsBuffer = colorsBuffer
        
        self.width = width
        self.height = height
        self.colors = colors
        
        // Create texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        self.textureCache = textureCache
        
        // Set up layer properties
        self.needsDisplayOnBoundsChange = true
        self.contentsScale = UIScreen.main.scale
    }
    
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
        self.width = meshGradientLayer.width
        self.height = meshGradientLayer.height
        self.colors = meshGradientLayer.colors
        
        super.init(layer: layer)
    }
    
    func traitCollectionDidChange() {
        let metalColors: [SIMD4<Float>] = colors.compactMap { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        
        let colorsBuffer = metalDevice?.makeBuffer(
            bytes: metalColors,
            length: MemoryLayout<SIMD4<Float>>.stride * metalColors.count
        )
        guard let colorsBuffer else {
            assertionFailure("Can't create colorsBuffer")
            return
        }
        self.colorsBuffer = colorsBuffer
    }
    
    // MARK: - Drawing
    
    public override func draw(in ctx: CGContext) {
        let width = Int(bounds.width * contentsScale)
        let height = Int(bounds.height * contentsScale)
        
        guard width > 0, height > 0 else { return }
        
        // Create a Metal texture that shares memory with a Core Graphics bitmap
        var texture: MTLTexture?
        
        // Create a Core Video pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            nil,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer")
            return
        }
        
        guard let pixelBuffer = pixelBuffer else { return }
        
        // Create a Metal texture from the pixel buffer
        var cvTexture: CVMetalTexture?
        guard let textureCache = textureCache else { return }
        
        let textureStatus = CVMetalTextureCacheCreateTextureFromImage(
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
        
        if textureStatus != kCVReturnSuccess {
            print("Failed to create CV metal texture")
            return
        }
        
        guard let cvTexture = cvTexture,
              let metalTexture = CVMetalTextureGetTexture(cvTexture) else {
            return
        }
        
        texture = metalTexture
        
        // Create a render pass descriptor with the texture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Create a command buffer and render command encoder
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set up rendering
        renderEncoder.setRenderPipelineState(pipelineState!)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(gridBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(colorsBuffer, offset: 0, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Commit the command buffer
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Create a Core Graphics image from the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert back to CGImage
        let ciContext = CIContext(options: [.outputColorSpace: CGColorSpaceCreateDeviceRGB()])
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        // Draw the CG image into the provided context
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(cgImage, in: bounds)
        ctx.restoreGState()
    }
}
