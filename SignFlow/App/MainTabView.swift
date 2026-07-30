import SwiftUI

enum MainTab: Hashable {
    case sources
    case library
    case settings
}

struct MainTabView: View {
    @State private var selection: MainTab = .library
    @State private var sourcesRouter = AppRouter()
    @State private var libraryRouter = AppRouter()
    @State private var settingsRouter = AppRouter()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $sourcesRouter.path) {
                SourcesView()
                    .navigationDestination(for: AppRoute.self) { AppRouteDestination(route: $0) }
            }
            .environment(sourcesRouter)
            .tag(MainTab.sources)
            .tabItem {
                Label("Sources", systemImage: "globe.desk")
            }

            NavigationStack(path: $libraryRouter.path) {
                AppLibraryView()
                    .navigationDestination(for: AppRoute.self) { AppRouteDestination(route: $0) }
            }
            .environment(libraryRouter)
            .tag(MainTab.library)
            .tabItem {
                Label("Library", systemImage: "square.grid.2x2")
            }

            NavigationStack(path: $settingsRouter.path) {
                SettingsView()
                    .navigationDestination(for: AppRoute.self) { AppRouteDestination(route: $0) }
            }
            .environment(settingsRouter)
            .tag(MainTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape.2")
            }
        }
        .tint(SignFlowTheme.accent)
    }
}
