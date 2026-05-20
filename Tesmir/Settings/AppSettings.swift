import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    @AppStorage("vehicleModel") var vehicleModel: VehicleModel = .model3 { willSet { objectWillChange.send() } }
    @AppStorage("vehicleGeneration") var vehicleGenerationRaw: String = VehicleGeneration.mcu2.rawValue { willSet { objectWillChange.send() } }
    var vehicleGeneration: VehicleGeneration {
        get { VehicleGeneration(rawValue: vehicleGenerationRaw) ?? .mcu2 }
        set { vehicleGenerationRaw = newValue.rawValue }
    }
    @AppStorage("qualityPreset") var qualityPresetRaw: String = QualityPreset.auto.rawValue { willSet { objectWillChange.send() } }
    var qualityPreset: QualityPreset {
        get { QualityPreset(rawValue: qualityPresetRaw) ?? .auto }
        set { qualityPresetRaw = newValue.rawValue }
    }
    @AppStorage("frameRateLimit") var frameRateLimit: Int = 12 { willSet { objectWillChange.send() } }
    @AppStorage("safeDrivingEnabled") var safeDrivingEnabled: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("serverPort") var serverPort: Int = 8080 { willSet { objectWillChange.send() } }
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false { willSet { objectWillChange.send() } }
    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
}

enum VehicleModel: String, CaseIterable, Codable {
    case model3 = "Model 3"
    case modelY = "Model Y"
    case modelS = "Model S"
    case modelX = "Model X"
    var displayName: String { rawValue }
    var icon: String { "car.fill" }
}
