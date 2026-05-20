import SwiftUI

struct OnboardingStep: Identifiable {
    let id: Int; let icon: String; let iconColor: Color
    let title: String; let subtitle: String; let detail: String; let badgeText: String?
}

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentStep = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(id: 0, icon: "iphone.radiowaves.left.and.right", iconColor: .blue,
            title: "핫스팟 활성화", subtitle: "Enable iPhone Hotspot",
            detail: "iPhone의 설정 > 개인용 핫스팟을 켜세요.\n'다른 사람의 연결 허용'을 활성화해 주세요.", badgeText: "Step 1"),
        OnboardingStep(id: 1, icon: "car.fill", iconColor: .green,
            title: "Tesla 연결", subtitle: "Connect Tesla to Hotspot",
            detail: "Tesla 터치스크린에서\n설정 > Wi-Fi > [iPhone 이름]\n을 선택해 핫스팟에 연결하세요.", badgeText: "Step 2"),
        OnboardingStep(id: 2, icon: "safari.fill", iconColor: .orange,
            title: "Tesla 브라우저 열기", subtitle: "Open URL in Tesla Browser",
            detail: "앱에서 미러링을 시작하면 표시되는 주소를\nTesla 브라우저 주소창에 입력하세요.\n예: http://172.20.10.1:8080", badgeText: "Step 3")
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                TabView(selection: $currentStep) {
                    ForEach(steps) { step in stepView(step).tag(step.id) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                bottomControls
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Tesmir").font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
            Text("테슬미르 · iPhone → Tesla Mirror").font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 60).padding(.bottom, 20)
    }

    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 32) {
            if let badge = step.badgeText {
                Text(badge).font(.caption.bold()).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(step.iconColor).clipShape(Capsule())
            }
            ZStack {
                Circle().fill(step.iconColor.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: step.icon).font(.system(size: 52)).foregroundColor(step.iconColor)
            }
            VStack(spacing: 12) {
                Text(step.title).font(.title2.bold())
                Text(step.subtitle).font(.subheadline).foregroundColor(.secondary)
                Text(step.detail).font(.callout).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 32)
            }
            Spacer()
        }.padding(.top, 20)
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    Circle().fill(currentStep == step.id ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: currentStep == step.id ? 10 : 7, height: currentStep == step.id ? 10 : 7)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button(action: { currentStep -= 1 }) {
                        Text("이전").frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color(.secondarySystemBackground)).foregroundColor(.primary).cornerRadius(14)
                    }.transition(.opacity)
                }
                Button(action: { currentStep < steps.count - 1 ? (currentStep += 1) : (isCompleted = true) }) {
                    Text(currentStep == steps.count - 1 ? "시작하기" : "다음").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }.padding(.horizontal, 24).animation(.easeInOut, value: currentStep)
            if currentStep < steps.count - 1 {
                Button(action: { isCompleted = true }) {
                    Text("건너뛰기").font(.caption).foregroundColor(.secondary)
                }
            }
        }.padding(.bottom, 48)
    }
}

#Preview { OnboardingView(isCompleted: .constant(false)) }
