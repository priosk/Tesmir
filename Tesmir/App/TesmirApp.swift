import SwiftUI

@main
struct TesmirApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appSettings)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView(isCompleted: $hasCompletedOnboarding)
        }
    }
}
