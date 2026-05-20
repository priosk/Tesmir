import Foundation
import Combine
import SwiftUI

enum NetworkQuality {
    case excellent, good, fair, poor, unknown
    var icon: String {
        switch self {
        case .excellent, .good: return "wifi"
        case .fair: return "wifi.exclamationmark"
        case .poor, .unknown: return "wifi.slash"
        }
    }
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor, .unknown: return .red
        }
    }
    var label: String {
        switch self {
        case .excellent: return "최상"
        case .good: return "양호"
        case .fair: return "보통"
        case .poor: return "불량"
        case .unknown: return "확인 중"
        }
    }
    var description: String {
        switch self {
        case .excellent: return "스트리밍 최적 상태"
        case .good: return "스트리밍 가능"
        case .fair: return "화질이 낙아질 수 있습니다"
        case .poor: return "연결 상태를 확인하세요"
        case .unknown: return "네트워크 감지 중..."
        }
    }
}

@MainActor
class MirroringViewModel: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isStarting: Bool = false
    @Published var connectedViewerCount: Int = 0
    @Published var localURL: String? = nil
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var currentFPS: Int = 0
    @Published var safeDrivingEnabled: Bool = true { didSet { safeDrivingGuard.isEnabled = safeDrivingEnabled } }
    @Published var errorMessage: String? = nil

    private let captureManager = ScreenCaptureManager()
    private let streamingServer = StreamingServer()
    private let networkMonitor = NetworkMonitor()
    private let safeDrivingGuard = SafeDrivingGuard()
    private var cancellables = Set<AnyCancellable>()
    private var fpsCounter: Int = 0
    private var fpsTimer: Timer?

    init() { setupBindings() }

    private func setupBindings() {
        networkMonitor.$localIPAddress.receive(on: DispatchQueue.main)
            .sink { [weak self] ip in
                guard let self, let ip, self.isRunning else { return }
                self.localURL = "http://\(ip):8080"
            }.store(in: &cancellables)

        networkMonitor.$networkQuality.receive(on: DispatchQueue.main)
            .assign(to: \.networkQuality, on: self).store(in: &cancellables)

        streamingServer.$connectedClients.receive(on: DispatchQueue.main)
            .assign(to: \.connectedViewerCount, on: self).store(in: &cancellables)

        captureManager.$latestFrameData.compactMap { $0 }
            .sink { [weak self] data in
                guard let self else { return }
                self.streamingServer.broadcastFrame(data)
                self.fpsCounter += 1
            }.store(in: &cancellables)

        safeDrivingGuard.$isDriving.receive(on: DispatchQueue.main)
            .sink { [weak self] isDriving in
                guard let self, self.safeDrivingEnabled, isDriving, self.isRunning else { return }
                self.captureManager.setQualityPreset(.low)
            }.store(in: &cancellables)
    }

    func startMirroring() {
        guard !isRunning && !isStarting else { return }
        isStarting = true; errorMessage = nil
        Task {
            do {
                networkMonitor.start()
                try streamingServer.start(port: 8080)
                try await captureManager.startCapture()
                startFPSTimer()
                if let ip = networkMonitor.localIPAddress { localURL = "http://\(ip):8080" }
                isRunning = true; isStarting = false
                safeDrivingGuard.start()
            } catch {
                isStarting = false
                errorMessage = "시작 실패: \(error.localizedDescription)"
            }
        }
    }

    func stopMirroring() {
        guard isRunning else { return }
        captureManager.stopCapture(); streamingServer.stop(); safeDrivingGuard.stop(); stopFPSTimer()
        isRunning = false; connectedViewerCount = 0; currentFPS = 0; localURL = nil
    }

    private func startFPSTimer() {
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.currentFPS = self.fpsCounter; self.fpsCounter = 0 }
        }
    }

    private func stopFPSTimer() {
        fpsTimer?.invalidate(); fpsTimer = nil; fpsCounter = 0
    }
}
