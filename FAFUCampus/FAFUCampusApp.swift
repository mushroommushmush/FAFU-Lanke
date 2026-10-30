import SwiftUI

@main @MainActor struct FAFUCampusApp: App {
    @StateObject private var store = CampusStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.forest)
                .task { await store.restoreOnLaunch() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await store.saveSessionOnBackground() } }
                }
                .alert("提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("知道了") { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
    }
}
