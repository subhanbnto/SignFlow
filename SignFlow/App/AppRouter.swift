import SwiftUI

enum AppRoute: Hashable {
    case dashboard
    case importIPA
    case inspecting(URL)
    case appDetails(AppPackage)
}

@Observable
final class AppRouter {
    var path = NavigationPath()

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
