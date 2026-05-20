import Foundation
import CoreMotion
import Combine

class SafeDrivingGuard: ObservableObject {
    @Published var isDriving: Bool = false
    @Published var isEnabled: Bool = true

    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private let drivingAccelerationThreshold: Double = 0.15
    private var recentAccelerations: [Double] = []
    private let sampleWindow = 10

    func start() {
        guard isEnabled else { return }
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                if activity.automotive { DispatchQueue.main.async { self?.isDriving = true } }
                else if activity.stationary || activity.walking { DispatchQueue.main.async { self?.isDriving = false } }
            }
        }
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.5
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.processAccelerometer(data)
            }
        }
    }

    func stop() {
        activityManager.stopActivityUpdates()
        motionManager.stopAccelerometerUpdates()
        isDriving = false
    }

    private func processAccelerometer(_ data: CMAccelerometerData) {
        let x = data.acceleration.x, y = data.acceleration.y, z = data.acceleration.z
        let dynamic = abs(sqrt(x*x + y*y + z*z) - 1.0)
        recentAccelerations.append(dynamic)
        if recentAccelerations.count > sampleWindow { recentAccelerations.removeFirst() }
        let avg = recentAccelerations.reduce(0, +) / Double(recentAccelerations.count)
        if !CMMotionActivityManager.isActivityAvailable() { isDriving = avg > drivingAccelerationThreshold }
    }
}
