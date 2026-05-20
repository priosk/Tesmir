import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var mirroringViewModel = MirroringViewModel()

    var body: some View {
        TabView {
            MirroringView()
                .environmentObject(mirroringViewModel)
                .tabItem {
                    Label("미러링", systemImage: "play.display")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
