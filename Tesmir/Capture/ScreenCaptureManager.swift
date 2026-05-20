import Foundation
import ReplayKit
import Combine
import CoreMedia

enum QualityPreset: String, CaseIterable {
    case auto = "Auto"
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var jpegQuality: CGFloat {
        switch self {
        case .auto: return 0.5
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.75
        }
    }

    var targetFPS: Int {
        switch self {
        case .auto: return 12
        case .low: return 8
        case .medium: return 12
        case .high: return 15
        }
    }
}

class ScreenCaptureManager: ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var latestFrameData: Data? = nil
    @Published var captureError: Error? = nil

    private let recorder = RPScreenRecorder.shared()
    private var videoEncoder: VideoEncoder
    private var currentPreset: QualityPreset = .auto
    private var lastFrameTime: CFTimeInterval = 0
    private var frameInterval: CFTimeInterval = 1.0 / 12.0

    init() {
        self.videoEncoder = VideoEncoder(quality: QualityPreset.auto.jpegQuality)
    }

    func setQualityPreset(_ preset: QualityPreset) {
        currentPreset = preset
        frameInterval = 1.0 / CFTimeInterval(preset.targetFPS)
        videoEncoder.quality = preset.jpegQuality
    }

    func startCapture() async throws {
        guard !isCapturing else { return }
        guard RPScreenRecorder.shared().isAvailable else {
            throw CaptureError.recorderUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async { self.captureError = error }
                    return
                }
                guard bufferType == .video else { return }
                let now = CACurrentMediaTime()
                guard now - self.lastFrameTime >= self.frameInterval else { return }
                self.lastFrameTime = now
                if let frameData = self.videoEncoder.encode(sampleBuffer: sampleBuffer) {
                    DispatchQueue.main.async { self.latestFrameData = frameData }
                }
            }, completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    DispatchQueue.main.async { self.isCapturing = true }
                    continuation.resume()
                }
            })
        }
    }

    func stopCapture() {
        guard isCapturing else { return }
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.latestFrameData = nil
                if let error { self?.captureError = error }
            }
        }
    }
}

enum CaptureError: LocalizedError {
    case recorderUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .recorderUnavailable: return "화면 녹화를 사용할 수 없습니다. 설정을 확인하세요."
        case .encodingFailed: return "프레임 인코딩에 실패했습니다."
        }
    }
}
