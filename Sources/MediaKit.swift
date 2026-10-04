import AppKit
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum MediaKit {
    static func normalizeJPEG(_ data: Data, maxEdge: CGFloat = 1280) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let jpeg: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.86]
        CGImageDestinationAddImage(destination, image, jpeg as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func pngData(from image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func gifData(frames: [CGImage], delay: Double) -> Data? {
        guard !frames.isEmpty else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }
        let fileProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProps as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func gif(fromVideo url: URL, maxFrames: Int = 16) async throws -> Data {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0.05 else {
            throw StudioError.message("视频太短，做不成动图")
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 854)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        let span = min(seconds, 4)
        let count = max(4, min(maxFrames, Int(span * 8)))
        var frames: [CGImage] = []
        for index in 0..<count {
            let fraction = count == 1 ? 0 : Double(index) / Double(count - 1)
            let time = CMTime(seconds: min(span * fraction, max(seconds - 0.05, 0)), preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append(image)
            }
        }
        guard let gif = gifData(frames: frames, delay: span / Double(max(frames.count, 1))) else {
            throw StudioError.message("动图导出失败")
        }
        return gif
    }

    static func fallbackModelPNG() -> Data {
        let width = 768
        let height = 1024
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Data() }
        context.setFillColor(CGColor(srgbRed: 0.93, green: 0.90, blue: 0.86, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0.90, green: 0.76, blue: 0.66, alpha: 1))
        context.fillEllipse(in: CGRect(x: 304, y: 640, width: 160, height: 190))
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.95, blue: 0.92, alpha: 1))
        context.fill(CGRect(x: 284, y: 360, width: 200, height: 280))
        context.setFillColor(CGColor(srgbRed: 0.18, green: 0.20, blue: 0.22, alpha: 1))
        context.fill(CGRect(x: 300, y: 80, width: 70, height: 300))
        context.fill(CGRect(x: 398, y: 80, width: 70, height: 300))
        guard let image = context.makeImage(), let png = pngData(from: image) else { return Data() }
        return png
    }
}
