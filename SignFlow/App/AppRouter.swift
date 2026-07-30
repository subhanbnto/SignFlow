import SwiftUI

enum AppRoute: Hashable {
    case importIPA
    case inspecting(URL)
    case appDetails(AppPackage)
    case libraryAppDetails(LibraryAppRecord)
    case certificates
    case certificateDetail(SigningIdentity)
    case importCertificate
    case profiles
    case profileDetail(ProvisioningProfile)
    case importProfile
    case signingSetup
    case signingSetupForLibrary(LibraryAppRecord)
    case preflight(SigningConfiguration)
    case signingProgress(SigningConfiguration)
    case signingResult(SigningJobResult)
    case sourceApps([AppSource])
    case sourceAppDetail(SourceApp)
    case appearance
    case signingOptions
    case archiveSettings
    case installationSettings
    case about
    case reset
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

struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .importIPA:
            ImportIPAView()
        case .inspecting(let url):
            InspectionProgressView(sourceURL: url)
        case .appDetails(let package):
            AppInspectorView(package: package)
        case .libraryAppDetails(let record):
            LibraryAppDetailView(record: record)
        case .certificates:
            CertificateListView()
        case .certificateDetail(let identity):
            CertificateDetailView(identity: identity)
        case .importCertificate:
            ImportCertificateView()
        case .profiles:
            ProfileListView()
        case .profileDetail(let profile):
            ProfileDetailView(profile: profile)
        case .importProfile:
            ImportProfileView()
        case .signingSetup:
            SigningSetupView()
        case .signingSetupForLibrary(let record):
            SigningSetupView(preselectedLibraryApp: record)
        case .preflight(let config):
            PreflightView(configuration: config)
        case .signingProgress(let config):
            SigningProgressView(configuration: config)
        case .signingResult(let result):
            SigningResultView(result: result)
        case .sourceApps(let sources):
            SourceAppsView(sources: sources)
        case .sourceAppDetail(let app):
            SourceAppDetailView(app: app)
        case .appearance:
            AppearanceSettingsView()
        case .signingOptions:
            SigningOptionsSettingsView()
        case .archiveSettings:
            ArchiveSettingsView()
        case .installationSettings:
            InstallationSettingsView()
        case .about:
            AboutSignFlowView()
        case .reset:
            ResetSettingsView()
        }
    }
}
