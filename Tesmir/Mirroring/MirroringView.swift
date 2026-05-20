import SwiftUI

struct MirroringView: View {
    @EnvironmentObject private var viewModel: MirroringViewModel
    @State private var showCopiedAlert = false
    @State private var showQRCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusCard
                    startStopButton
                    if viewModel.isRunning, let url = viewModel.localURL { urlSection(url: url) }
                    if viewModel.isRunning { networkQualitySection }
                    safeDrivingToggle
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Tesmir 테슬미르")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showQRCode) {
                if let url = viewModel.localURL { QRCodeSheet(urlString: url) }
            }
            .overlay(alignment: .top) {
                if showCopiedAlert { copiedToast }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(viewModel.isRunning ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(viewModel.isRunning ? Color.green.opacity(0.3) : Color.clear, lineWidth: 6)
                    .scaleEffect(viewModel.isRunning ? 1.8 : 1)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: viewModel.isRunning))
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isRunning ? "스트리밍 중" : "대기 중").font(.headline)
                    .foregroundColor(viewModel.isRunning ? .green : .secondary)
                Text(viewModel.isRunning ? "연결된 기기: \(viewModel.connectedViewerCount)개" : "시작 버튼을 눌러 미러링을 시작하세요")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if viewModel.isRunning {
                VStack(spacing: 2) {
                    Text("\(viewModel.currentFPS)").font(.title3.bold()).foregroundColor(.blue)
                    Text("FPS").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.blue.opacity(0.1)).cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var startStopButton: some View {
        Button(action: { viewModel.isRunning ? viewModel.stopMirroring() : viewModel.startMirroring() }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isRunning ? "stop.circle.fill" : "play.circle.fill").font(.title2)
                Text(viewModel.isRunning ? "미러링 중지" : "미러링 시작").font(.title3.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(viewModel.isRunning ? Color.red : Color.blue)
            .foregroundColor(.white).cornerRadius(16)
        }
        .disabled(viewModel.isStarting)
        .overlay {
            if viewModel.isStarting {
                RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.2))
                ProgressView().tint(.white)
            }
        }
    }

    private func urlSection(url: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tesla 브라우저에서 열기").font(.subheadline.bold()).foregroundColor(.secondary)
            HStack {
                Text(url).font(.system(.body, design: .monospaced)).foregroundColor(.blue).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = url
                    withAnimation { showCopiedAlert = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showCopiedAlert = false } }
                }) { Image(systemName: "doc.on.doc").foregroundColor(.blue) }
                Button(action: { showQRCode = true }) { Image(systemName: "qrcode").foregroundColor(.blue) }
            }
            .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
            Text("위 주소를 Tesla 브라우저 주소창에 입력하세요").font(.caption).foregroundColor(.secondary)
        }
        .padding().background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var networkQualitySection: some View {
        HStack(spacing: 16) {
            Image(systemName: viewModel.networkQuality.icon).font(.title3).foregroundColor(viewModel.networkQuality.color)
            VStack(alignment: .leading, spacing: 4) {
                Text("네트워크 상태").font(.subheadline.bold())
                Text(viewModel.networkQuality.description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(viewModel.networkQuality.label).font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(viewModel.networkQuality.color.opacity(0.15))
                .foregroundColor(viewModel.networkQuality.color).cornerRadius(6)
        }
        .padding().background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var safeDrivingToggle: some View {
        HStack(spacing: 16) {
            Image(systemName: "car.circle.fill").font(.title3).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("안전 운전 모드").font(.subheadline.bold())
                Text("주행 중 화면 잠금 활성화").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $viewModel.safeDrivingEnabled).labelsHidden()
        }
        .padding().background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var copiedToast: some View {
        Text("주소가 복사되었습니다").font(.callout.bold())
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.black.opacity(0.8)).foregroundColor(.white).cornerRadius(20)
            .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct QRCodeSheet: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("QR 코드를 스캔하세요").font(.headline).foregroundColor(.secondary)
                if let qrImage = QRCodeGenerator.generate(from: urlString) {
                    Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit()
                        .frame(width: 240, height: 240).padding()
                        .background(Color.white).cornerRadius(16).shadow(radius: 8)
                }
                Text(urlString).font(.system(.callout, design: .monospaced)).foregroundColor(.blue).multilineTextAlignment(.center)
                Text("Tesla 브라우저에서 위 주소를 직접 입력하거나\n다른 기기로 QR 코드를 스캔하세요")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("QR 코드").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}

#Preview { MirroringView().environmentObject(MirroringViewModel()) }
