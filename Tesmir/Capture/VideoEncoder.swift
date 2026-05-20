import Foundation
import CoreMedia
import CoreVideo
import CoreImage
import UIKit

class VideoEncoder {
    var quality: CGFloat
    private let ciContext: CIContext
    var scaleFactor: CGFloat = 0.75
    var vehicleGeneration: VehicleGeneration = .mcu2 {
        didSet { updateQualityForGeneration() }
    }

    init(quality: CGFloat = 0.5) {
        self.quality = quality
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: metalDevice, options: [.workingColorSpace: NSNull()])
        } else {
            self.ciContext = CIContext(options: [.workingColorSpace: NSNull()])
        }
    }

    func encode(sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return encode(pixelBuffer: pixelBuffer)
    }

    func encode(pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaledImage = scaleFactor < 1.0
            ? ciImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            : ciImage
        let extent = scaledImage.extent
        guard let cgImage = ciContext.createCGImage(scaledImage, from: extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }

    private func updateQualityForGeneration() {
        switch vehicleGeneration {
        case .mcu1: quality = min(quality, 0.3); scaleFactor = 0.5
        case .mcu2: quality = min(quality, 0.5); scaleFactor = 0.65
        case .mcu3: scaleFactor = 0.85
        }
    }
}

enum VehicleGeneration: String, CaseIterable {
    case mcu1 = "MCU1"
    case mcu2 = "MCU2"
    case mcu3 = "MCU3"

    var displayName: String {
        switch self {
        case .mcu1: return "MCU1 (Model S/X 2017 이전)"
        case .mcu2: return "MCU2 (2018–2021)"
        case .mcu3: return "MCU3 (2022+)"
        }
    }

    var recommendedQuality: CGFloat {
        switch self {
        case .mcu1: return 0.3
        case .mcu2: return 0.45
        case .mcu3: return 0.65
        }
    }

    var recommendedFPS: Int {
        switch self {
        case .mcu1: return 6
        case .mcu2: return 10
        case .mcu3: return 15
        }
    }
}
