// Renders the studio cards (Assets.xcassets/render_<model>.png) with RealityKit: the renderer, materials, lights and
// image-based light of the live stage (ios/Timbre/Stage/InstrumentStage.swift, StageController and StageLighting), so the
// instrument on a card is the instrument the player tunes. The camera is the one the cards were first rendered with
// (tools/models/sketchfab/convert.py: 85 mm lens on a 24 mm sensor, 24 degrees round to the right, 6 degrees up, the
// instrument 1.08 times its height in frame), so each rig's card2D points stay where they were.
//
//   xcrun swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos15.0 tools/models/render_cards.swift -o build/render-cards
//   build/render-cards ios/Timbre/Resources/Models build/cards [--size 1024] [--supersample 2] [--models a,b] [--variants a,b]
//
// macOS 15 or later (RealityRenderer). Writes, for every model with a usdz and a rig and every variant:
//   cards/<variant>/render_<model>.png   1024 x 1024 RGBA, straight alpha, sRGB (the card)
//   closeups/<model>_<variant>.png       the phone stage's close-up of the head (review only; acoustic guitar and mandolin)
//   RENDER.txt                           how each card was matted, its coverage and mean colour
// Variants differ only in how RealityRenderer's output is read (8-bit sRGB, 8-bit unorm, half float) and whether it tone
// maps; tools/models/cards.py sheet lays them beside the live stage so one can be picked and installed.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Metal
import RealityKit
import simd
import UniformTypeIdentifiers

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The parts of <model>.rig.json the renderer needs (the app's InstrumentRig).
struct Rig: Decodable {
    struct StringRig: Decodable {
        let anchor: String
        let nut: [Float]
        let pegCenter: [Float]
    }
    let model: String
    let length: Float
    let headCenter: [Float]
    let boundsMin: [Float]
    let boundsMax: [Float]
    let strings: [StringRig]
}

func point3(_ a: [Float]) -> SIMD3<Float> {
    SIMD3<Float>(a.count > 0 ? a[0] : 0, a.count > 1 ? a[1] : 0, a.count > 2 ? a[2] : 0)
}

/// How RealityRenderer's colour output is stored and read.
struct Variant {
    let name: String
    let format: MTLPixelFormat
    let toneMapping: Bool
    var isHalf: Bool { format == .rgba16Float }
}

let allVariants: [Variant] = [
    Variant(name: "srgb8-tm", format: .rgba8Unorm_srgb, toneMapping: true),
    Variant(name: "srgb8-flat", format: .rgba8Unorm_srgb, toneMapping: false),
    Variant(name: "unorm8-tm", format: .rgba8Unorm, toneMapping: true),
    Variant(name: "unorm8-flat", format: .rgba8Unorm, toneMapping: false),
    Variant(name: "half-tm", format: .rgba16Float, toneMapping: true),
    Variant(name: "half-flat", format: .rgba16Float, toneMapping: false),
]

/// Models whose phone close-up is rendered for the review sheet (the live stage captures 10-tune-3d and 49-tune-mandolin-3d).
let closeUpModels: Set<String> = ["guitar_acoustic", "mandolin"]

struct Options {
    var modelsDir = URL(fileURLWithPath: "ios/Timbre/Resources/Models")
    var outDir = URL(fileURLWithPath: "build/cards")
    var size = 1024
    var supersample = 2
    var models: Set<String> = []
    var variants: Set<String> = []

    init(_ arguments: [String]) throws {
        var positional: [String] = []
        var index = 1
        func value() throws -> String {
            index += 1
            guard index < arguments.count else { throw Failure("missing value for \(arguments[index - 1])") }
            return arguments[index]
        }
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--size":
                let text = try value()
                size = Int(text) ?? size
            case "--supersample":
                let text = try value()
                supersample = max(1, Int(text) ?? supersample)
            case "--models":
                let text = try value()
                models = Set(text.split(separator: ",").map(String.init))
            case "--variants":
                let text = try value()
                variants = Set(text.split(separator: ",").map(String.init))
            default: positional.append(argument)
            }
            index += 1
        }
        if positional.count > 0 { modelsDir = URL(fileURLWithPath: positional[0]) }
        if positional.count > 1 { outDir = URL(fileURLWithPath: positional[1]) }
    }
}

/// The live stage's environment, as StageLighting.environmentImage() draws it: dark warm stage, key softbox, cool rim.
enum StageLighting {
    static func environmentImage(width: Int = 512, height: Int = 256) -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.035, green: 0.03, blue: 0.028, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        func softbox(_ u: CGFloat, _ v: CGFloat, _ radius: CGFloat, _ color: (CGFloat, CGFloat, CGFloat)) {
            let colors = [CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1), CGColor(red: color.0, green: color.1, blue: color.2, alpha: 0)] as CFArray
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: u * CGFloat(width), y: v * CGFloat(height))
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius * CGFloat(width), options: [])
        }
        softbox(0.38, 0.72, 0.13, (1.0, 0.86, 0.68))   // key: front-left, high
        softbox(0.86, 0.6, 0.09, (0.62, 0.76, 1.0))    // rim: behind-right
        softbox(0.6, 0.45, 0.16, (0.32, 0.26, 0.2))    // warm bounce
        return context.makeImage()
    }
}

// MARK: - Pixels

func srgbToLinear(_ c: Float) -> Float { c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4) }
func linearToSRGB(_ c: Float) -> Float { c <= 0.0031308 ? c * 12.92 : 1.055 * powf(c, 1 / 2.4) - 0.055 }

func halfToFloat(_ h: UInt16) -> Float {
    let sign: Float = (h & 0x8000) != 0 ? -1 : 1
    let exponent = Int((h >> 10) & 0x1f)
    let mantissa = Float(h & 0x3ff)
    if exponent == 0 { return sign * mantissa * powf(2, -24) }
    if exponent == 31 { return mantissa == 0 ? sign * Float.infinity : Float.nan }
    return sign * (1 + mantissa / 1024) * powf(2, Float(exponent - 15))
}

/// An image as linear-light RGBA floats, row 0 at the top.
struct Pixels {
    let width: Int
    let height: Int
    var data: [Float]

    func corner(_ channel: Int) -> Float {
        var sum: Float = 0
        var count: Float = 0
        let n = 8
        for (x0, y0) in [(0, 0), (width - n, 0), (0, height - n), (width - n, height - n)] {
            for y in y0..<(y0 + n) {
                for x in x0..<(x0 + n) {
                    sum += data[(y * width + x) * 4 + channel]
                    count += 1
                }
            }
        }
        return sum / count
    }
}

/// Copies the texture into shared memory and decodes it to linear floats. 8-bit output is read as display-encoded
/// (sRGB) values, half-float output as linear light.
@MainActor
func readTexture(_ texture: MTLTexture, variant: Variant, device: MTLDevice, queue: MTLCommandQueue) throws -> Pixels {
    let width = texture.width, height = texture.height
    let bytesPerPixel = variant.isHalf ? 8 : 4
    let rowBytes = width * bytesPerPixel
    guard let buffer = device.makeBuffer(length: rowBytes * height, options: .storageModeShared),
          let commands = queue.makeCommandBuffer(), let blit = commands.makeBlitCommandEncoder() else { throw Failure("could not read the texture back") }
    blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
              sourceSize: MTLSize(width: width, height: height, depth: 1), to: buffer, destinationOffset: 0,
              destinationBytesPerRow: rowBytes, destinationBytesPerImage: rowBytes * height)
    blit.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()
    var data = [Float](repeating: 0, count: width * height * 4)
    if variant.isHalf {
        let raw = buffer.contents().bindMemory(to: UInt16.self, capacity: width * height * 4)
        for i in 0..<(width * height * 4) {
            let v = halfToFloat(raw[i])
            data[i] = v.isFinite ? max(0, v) : 0
        }
    } else {
        let raw = buffer.contents().bindMemory(to: UInt8.self, capacity: width * height * 4)
        for i in 0..<(width * height) {
            for c in 0..<3 { data[i * 4 + c] = srgbToLinear(Float(raw[i * 4 + c]) / 255) }
            data[i * 4 + 3] = Float(raw[i * 4 + 3]) / 255
        }
    }
    return Pixels(width: width, height: height, data: data)
}

/// Averages factor x factor blocks (premultiplied linear light, so edges stay clean).
func downsample(_ image: Pixels, by factor: Int) -> Pixels {
    guard factor > 1 else { return image }
    let w = image.width / factor, h = image.height / factor
    var out = [Float](repeating: 0, count: w * h * 4)
    let k = 1 / Float(factor * factor)
    for y in 0..<h {
        for x in 0..<w {
            for c in 0..<4 {
                var sum: Float = 0
                for dy in 0..<factor {
                    let row = (y * factor + dy) * image.width
                    for dx in 0..<factor { sum += image.data[(row + x * factor + dx) * 4 + c] }
                }
                out[(y * w + x) * 4 + c] = sum * k
            }
        }
    }
    return Pixels(width: w, height: h, data: out)
}

/// Premultiplied linear RGBA to straight-alpha sRGB bytes.
func encode(_ image: Pixels, opaque: Bool) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    for i in 0..<(image.width * image.height) {
        let a = opaque ? 1 : min(1, max(0, image.data[i * 4 + 3]))
        if a <= 0.0005 { continue }
        for c in 0..<3 {
            let straight = min(1, max(0, image.data[i * 4 + c] / a))
            bytes[i * 4 + c] = UInt8((linearToSRGB(straight) * 255).rounded())
        }
        bytes[i * 4 + 3] = UInt8((a * 255).rounded())
    }
    return bytes
}

func writePNG(_ bytes: [UInt8], width: Int, height: Int, alpha: Bool, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let info = alpha ? CGImageAlphaInfo.last : CGImageAlphaInfo.noneSkipLast
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                              space: space, bitmapInfo: CGBitmapInfo(rawValue: info.rawValue), provider: provider,
                              decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure("could not encode \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("could not write \(url.path)") }
}

// MARK: - Stage

/// One instrument on the live stage's set: the key and rim lights and the image-based light of StageController, the camera
/// at the origin looking down -Z, and the instrument moved in front of it (as the app frames it).
@MainActor
final class Stage {
    let renderer: RealityRenderer
    let device: MTLDevice
    let queue: MTLCommandQueue
    let camera = PerspectiveCamera()
    let holder = Entity()
    let light = Entity()
    let key = DirectionalLight()
    let rim = DirectionalLight()

    init(device: MTLDevice, queue: MTLCommandQueue, environment: EnvironmentResource, model: Entity) throws {
        self.device = device
        self.queue = queue
        renderer = try RealityRenderer()
        // StageController.setEnvironment: one image-based light, received by every part of the model.
        light.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: 0.4))
        renderer.lighting.resource = environment
        renderer.lighting.intensityExponent = 0.4
        // StageController.addLights.
        key.name = "stage.key"
        key.light.color = NSColor(red: 1, green: 0.88, blue: 0.74, alpha: 1)
        key.light.intensity = 2600
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
        key.look(at: [0, 0, -2], from: [-1.4, 1.8, 1.2], relativeTo: nil)
        rim.name = "stage.rim"
        rim.light.color = NSColor(red: 0.7, green: 0.82, blue: 1, alpha: 1)
        rim.light.intensity = 1500
        rim.look(at: [0, 0, -2], from: [1.6, 0.8, -4.2], relativeTo: nil)
        camera.position = .zero
        holder.addChild(model)
        receiveImageBasedLight(holder)
        renderer.entities.append(camera)
        renderer.entities.append(key)
        renderer.entities.append(rim)
        renderer.entities.append(light)
        renderer.entities.append(holder)
        renderer.activeCamera = camera
        renderer.cameraSettings.antialiasing = .multisample4X
    }

    private func receiveImageBasedLight(_ entity: Entity) {
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        for child in entity.children { receiveImageBasedLight(child) }
    }

    /// The card camera (convert.py's persp_camera(target, height, 24, 6, 85)), as a placement of the instrument in front
    /// of the stage camera. Returns the vertical field of view and the camera's distance from the instrument's centre.
    func placeForCard(_ rig: Rig) -> (fov: Float, distance: Float) {
        let lower = point3(rig.boundsMin), upper = point3(rig.boundsMax)
        let target = (lower + upper) / 2
        let fov = 2 * atanf(12 / 85)
        let distance = ((upper.y - lower.y) * 1.08 / 2) / tanf(fov / 2)
        let azimuth: Float = 24 * .pi / 180, elevation: Float = 6 * .pi / 180
        let direction = SIMD3<Float>(sinf(azimuth) * cosf(elevation), sinf(elevation), cosf(azimuth) * cosf(elevation))
        let eye = target + direction * distance
        let back = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        let look = simd_quatf(simd_float3x3(columns: (right, up, back)))
        holder.orientation = look.inverse
        holder.position = look.inverse.act(-eye)
        camera.camera.fieldOfViewInDegrees = fov * 180 / .pi
        // The whole instrument lies about `distance` away: keep its shadows inside the shadow map.
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: distance + rig.length + 0.5, depthBias: 2)
        return (fov, distance)
    }

    /// The phone stage's close-up of the head on the first string (StageController.closeUp at framing 1, the
    /// controls inset applied), for a stage of `size` points.
    func placeForCloseUp(_ rig: Rig, size: CGSize) {
        let fov: Float = 30 * .pi / 180
        let head = point3(rig.headCenter)
        var aim = head + SIMD3<Float>(0, -0.045, 0)
        if let first = rig.strings.first { aim = head + (point3(first.pegCenter) - head) * 0.45 + SIMD3<Float>(0, -0.03, 0) }
        var distance = max(0.34, (point3(rig.boundsMax).y - point3(rig.boundsMin).y) * 0.33)
        let height = Float(size.height)
        let pegClearance: Float = 48, nutClearance: Float = 30
        let turn = simd_quatf(angle: -0.54, axis: [0, 1, 0])
        if height > pegClearance + nutClearance + 40, !rig.strings.isEmpty {
            let t = tanf(fov / 2)
            let top = 1 - 2 * pegClearance / height
            let bottom = 1 - 2 * nutClearance / height
            var highest = -Float.greatestFiniteMagnitude
            var lowest = Float.greatestFiniteMagnitude
            for string in rig.strings {
                let peg = point3(string.pegCenter), nut = point3(string.nut)
                highest = max(highest, peg.y + top * turn.act(peg - aim).z * t)
                lowest = min(lowest, nut.y - bottom * turn.act(nut - aim).z * t)
            }
            distance = max(distance, (highest - lowest) / ((top + bottom) * t))
            let minAim = highest - top * distance * t
            let maxAim = max(minAim, lowest + bottom * distance * t)
            aim.y = min(max(aim.y, minAim), maxAim)
        }
        let metresPerPoint = height > 0 ? distance * tanf(fov / 2) / (height / 2) : 0
        let shift = 26 * metresPerPoint
        holder.orientation = turn
        holder.position = -turn.act(aim) + SIMD3<Float>(-shift, 0, -distance)
        camera.camera.fieldOfViewInDegrees = 30
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
    }

    /// Renders `frames` frames into a fresh texture and reads the last one back.
    func render(width: Int, height: Int, variant: Variant, background: CGColor, frames: Int) async throws -> Pixels {
        renderer.cameraSettings.colorBackground = .color(background)
        renderer.cameraSettings.isToneMappingEnabled = variant.toneMapping
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: variant.format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw Failure("no \(variant.name) texture") }
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        for _ in 0..<max(1, frames) {
            try await frame(output)
        }
        return try readTexture(texture, variant: variant, device: device, queue: queue)
    }

    private func frame(_ output: RealityRenderer.CameraOutput) async throws {
        let renderer = self.renderer
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try renderer.updateAndRender(deltaTime: 1.0 / 60.0, cameraOutput: output, onComplete: { _ in
                    continuation.resume()
                })
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Cards

struct CardResult {
    let image: Pixels
    let matte: String
}

/// The card with its alpha: colour from a pass over opaque black (premultiplied by construction), alpha from a pass over
/// a transparent background when the output keeps it, else from the difference between the black and a white pass.
@MainActor
func renderCard(_ stage: Stage, side: Int, variant: Variant, frames: Int) async throws -> CardResult {
    let black = try await stage.render(width: side, height: side, variant: variant,
                                       background: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1), frames: frames)
    let clear = try await stage.render(width: side, height: side, variant: variant,
                                       background: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0), frames: 3)
    var opaque = 0
    for i in stride(from: 3, to: clear.data.count, by: 4) where clear.data[i] > 0.99 { opaque += 1 }
    let pixels = side * side
    var out = black
    var matte: String
    if clear.corner(3) < 0.02, opaque > pixels / 200, opaque < pixels * 95 / 100 {
        matte = "alpha"
        for i in 0..<pixels { out.data[i * 4 + 3] = clear.data[i * 4 + 3] }
    } else {
        matte = "black-white"
        let white = try await stage.render(width: side, height: side, variant: variant,
                                           background: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), frames: 3)
        let backgroundBlack = (0..<3).map { black.corner($0) }
        let backgroundWhite = (0..<3).map { white.corner($0) }
        let span = max(0.05, (0..<3).map { backgroundWhite[$0] - backgroundBlack[$0] }.reduce(0, +) / 3)
        for i in 0..<pixels {
            var difference: Float = 0
            for c in 0..<3 { difference += white.data[i * 4 + c] - black.data[i * 4 + c] }
            let a = min(1, max(0, 1 - difference / 3 / span))
            for c in 0..<3 { out.data[i * 4 + c] = max(0, black.data[i * 4 + c] - (1 - a) * backgroundBlack[c]) }
            out.data[i * 4 + 3] = a
        }
        matte += String(format: " (background %.3f to %.3f)", backgroundBlack.reduce(0, +) / 3, backgroundWhite.reduce(0, +) / 3)
    }
    return CardResult(image: out, matte: matte)
}

/// Coverage and mean sRGB colour of the card's opaque pixels, for the log.
func describe(_ image: Pixels) -> String {
    var covered = 0
    var sum = SIMD3<Float>(repeating: 0)
    for i in 0..<(image.width * image.height) {
        let a = image.data[i * 4 + 3]
        guard a > 0.5 else { continue }
        covered += 1
        for c in 0..<3 { sum[c] += linearToSRGB(min(1, image.data[i * 4 + c] / a)) }
    }
    let mean = covered > 0 ? sum / Float(covered) * 255 : .zero
    return String(format: "coverage %.1f%% mean sRGB (%.0f, %.0f, %.0f)", Double(covered) * 100 / Double(image.width * image.height),
                  mean.x, mean.y, mean.z)
}

@MainActor
func run() async throws {
    setvbuf(stdout, nil, _IOLBF, 0)
    let options = try Options(CommandLine.arguments)
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
        throw Failure("no Metal device")
    }
    print("Metal device: \(device.name); macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
    guard let environmentImage = StageLighting.environmentImage() else { throw Failure("no environment image") }
    let environment = try await EnvironmentResource(equirectangular: environmentImage, withName: "timbre.stage")
    let variants = allVariants.filter { options.variants.isEmpty || options.variants.contains($0.name) }
    let rigs = try FileManager.default.contentsOfDirectory(at: options.modelsDir, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasSuffix(".rig.json") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    var log: [String] = ["size=\(options.size) supersample=\(options.supersample) device=\(device.name)"]
    var failures = 0
    for rigURL in rigs {
        let id = String(rigURL.lastPathComponent.dropLast(".rig.json".count))
        guard options.models.isEmpty || options.models.contains(id) else { continue }
        let usdz = options.modelsDir.appendingPathComponent("\(id).usdz")
        guard FileManager.default.fileExists(atPath: usdz.path) else { print("skip \(id): no usdz"); continue }
        do {
            let rig = try JSONDecoder().decode(Rig.self, from: Data(contentsOf: rigURL))
            let started = Date()
            let model = try await Entity(contentsOf: usdz)
            let stage = try Stage(device: device, queue: queue, environment: environment, model: model)
            let side = options.size * options.supersample
            var warm = true
            for variant in variants {
                _ = stage.placeForCard(rig)
                // The first pass of a model waits for its textures and shadows to settle.
                let card = try await renderCard(stage, side: side, variant: variant, frames: warm ? 24 : 4)
                warm = false
                let small = downsample(card.image, by: options.supersample)
                let url = options.outDir.appendingPathComponent("cards/\(variant.name)/render_\(id).png")
                try writePNG(encode(small, opaque: false), width: small.width, height: small.height, alpha: true, to: url)
                let line = "\(id) \(variant.name): matte \(card.matte), \(describe(small))"
                print(line)
                log.append(line)
                if closeUpModels.contains(id) {
                    let points = CGSize(width: 402, height: 300)
                    stage.placeForCloseUp(rig, size: points)
                    let stageColour = CGColor(srgbRed: 0.075, green: 0.062, blue: 0.05, alpha: 1)
                    let close = try await stage.render(width: Int(points.width) * 3, height: Int(points.height) * 3,
                                                       variant: variant, background: stageColour, frames: 4)
                    try writePNG(encode(close, opaque: true), width: close.width, height: close.height, alpha: false,
                                 to: options.outDir.appendingPathComponent("closeups/\(id)_\(variant.name).png"))
                }
            }
            print(String(format: "%@ done in %.1f s", id, Date().timeIntervalSince(started)))
        } catch {
            failures += 1
            let line = "\(id) FAILED: \(error)"
            print(line)
            log.append(line)
        }
    }
    try FileManager.default.createDirectory(at: options.outDir, withIntermediateDirectories: true)
    try (log.joined(separator: "\n") + "\n").write(to: options.outDir.appendingPathComponent("RENDER.txt"), atomically: true, encoding: .utf8)
    if failures > 0 { throw Failure("\(failures) model(s) failed") }
}

@main
struct RenderCards {
    @MainActor
    static func main() async {
        // A render that never completes must not hold the runner until the job's timeout.
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1500)) {
            FileHandle.standardError.write("render-cards: timed out\n".data(using: .utf8)!)
            exit(3)
        }
        do {
            try await run()
        } catch {
            print("render-cards: \(error)")
            exit(1)
        }
    }
}
