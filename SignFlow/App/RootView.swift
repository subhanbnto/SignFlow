import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            DashboardView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .dashboard:
                        DashboardView()
                    case .importIPA:
                        ImportIPAView()
                    case .inspecting(let url):
                        InspectionProgressView(sourceURL: url)
                    case .appDetails(let package):
                        AppInspectorView(package: package)
                    }
                }
        }
        .environment(router)
        .task {
            await environment.cleanupOrphanedWorkspaces()
        }
    }
}
