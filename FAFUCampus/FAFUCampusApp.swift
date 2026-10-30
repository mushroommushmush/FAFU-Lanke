import SwiftUI

@main @MainActor struct FAFUCampusApp: App {
    @StateObject private var store = CampusStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.forest)
                .overlay {
                    if scenePhase != .active {
                        Palette.background.ignoresSafeArea()
                            .overlay(Image(systemName: "leaf.fill").font(.system(size: 56)).foregroundStyle(Palette.forest))
                    }
                }
                .alert("提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("知道了") { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
    }
}
