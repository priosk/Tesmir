import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            List {
                Section { vehicleModelPicker; vehicleGenerationPicker }
                    header: { Label("차량 설정", systemImage: "car.fill") }
                    footer: { Text("MCU 버전에 따라 자동으로 화질이 최적화됩니다.") }

                Section { qualityPresetPicker; frameRateStepper }
                    header: { Label("화질 설정", systemImage: "video.fill") }
                    footer: { Text("Tesla MCU2 이하는 Low/Medium을 권장합니다.") }

                Section { safeDrivingToggle }
                    header: { Label("안전 설정", systemImage: "shield.fill") }
                    footer: { Text("주행 중 감지되면 화면 전송을 제한합니다.") }

                Section { serverPortRow }
                    header: { Label("서버 설정", systemImage: "network") }
                    footer: { Text("기본 포트는 8080입니다.") }

                Section { vpnHintRow } header: { Label("VPN 안내", systemImage: "lock.shield.fill") }

                Section { aboutRow } header: { Label("앱 정보", systemImage: "info.circle.fill") }
            }
            .navigationTitle("설정").navigationBarTitleDisplayMode(.large)
        }
    }

    private var vehicleModelPicker: some View {
        Picker(selection: $settings.vehicleModel) {
            ForEach(VehicleModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
        } label: { Label("차량 모델", systemImage: "car") }
    }

    private var vehicleGenerationPicker: some View {
        Picker(selection: Binding(get: { settings.vehicleGeneration }, set: { settings.vehicleGeneration = $0 })) {
            ForEach(VehicleGeneration.allCases, id: \.self) { Text($0.displayName).tag($0) }
        } label: { Label("MCU 버전", systemImage: "cpu") }
    }

    private var qualityPresetPicker: some View {
        Picker(selection: Binding(get: { settings.qualityPreset }, set: { settings.qualityPreset = $0 })) {
            ForEach(QualityPreset.allCases, id: \.self) { preset in
                VStack(alignment: .leading) {
                    Text(preset.rawValue)
                    Text("JPEG \(Int(preset.jpegQuality * 100))% · \(preset.targetFPS)fps").font(.caption).foregroundColor(.secondary)
                }.tag(preset)
            }
        } label: { Label("화질 프리셋", systemImage: "dial.medium") }
    }

    private var frameRateStepper: some View {
        Stepper(value: $settings.frameRateLimit, in: 5...30, step: 1) {
            HStack {
                Label("최대 프레임률", systemImage: "speedometer")
                Spacer()
                Text("\(settings.frameRateLimit) FPS").font(.callout).foregroundColor(.secondary)
            }
        }
    }

    private var safeDrivingToggle: some View {
        Toggle(isOn: $settings.safeDrivingEnabled) { Label("안전 운전 모드", systemImage: "car.circle.fill") }.tint(.orange)
    }

    private var serverPortRow: some View {
        HStack {
            Label("포트", systemImage: "number")
            Spacer()
            Text("\(settings.serverPort)").foregroundColor(.secondary).font(.callout)
        }
    }

    private var vpnHintRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VPN 사용 시 주의").font(.subheadline.bold())
            Text("iPhone에 VPN이 활성화되어 있으면 핫스팟을 통한 로컈 네트워크 접근이 차단될 수 있습니다. 미러링 사용 중에는 VPN을 일시 비활성화해 주세요.")
                .font(.caption).foregroundColor(.secondary)
        }.padding(.vertical, 4)
    }

    private var aboutRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text("버전"); Spacer(); Text("\(settings.appVersion) (\(settings.buildNumber))").foregroundColor(.secondary) }
            HStack {
                Text("Tesmir 테슬미르").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("made for Tesla").font(.caption).foregroundColor(.secondary)
            }
        }.padding(.vertical, 4)
    }
}

#Preview { SettingsView().environmentObject(AppSettings()) }
