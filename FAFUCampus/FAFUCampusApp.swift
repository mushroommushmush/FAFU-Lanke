import SwiftUI

@main @MainActor struct FAFUCampusApp: App {
    @StateObject private var store = CampusStore()
    @StateObject private var planner = Planner()
    @StateObject private var activities = LessonActivityManager()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView()
                .background { ActivityCoordinator() }
                .environmentObject(store)
                .environmentObject(planner)
                .environmentObject(activities)
                .tint(Palette.forest)
                .task {
                    if ProcessInfo.processInfo.arguments.contains("--layout-preview") {
                        UserDefaults.standard.set(true, forKey: "lanke.schedule.grid")
                        UserDefaults.standard.set(false, forKey: "lanke.live.enabled.v2")
                        store.openDemo()
                    } else { await store.restoreOnLaunch() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await store.saveSessionOnBackground() } }
                }
                .alert("提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("知道了") { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
    }
}
