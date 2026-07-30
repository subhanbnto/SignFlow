import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(SignFlowPreferences.appearanceStyleKey) private var appearanceStyle = AppearanceStyleSetting.system.rawValue

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                NavigationStack {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .task {
            await environment.cleanupOrphanedWorkspaces()
            await environment.refreshExpirationWarnings()
            await environment.refreshLibrary()
            await environment.refreshSources()
        }
    }

    private var colorScheme: ColorScheme? {
        switch AppearanceStyleSetting(rawValue: appearanceStyle) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
