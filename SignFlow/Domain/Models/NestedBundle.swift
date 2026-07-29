import Foundation

struct NestedBundle: Identifiable, Hashable, Sendable {
    let id: UUID
    let type: NestedBundleType
    let relativePath: String
    let bundleIdentifier: String
    let executableName: String?
    let version: String?
    let parentBundleIdentifier: String?
    let nestedComponents: [NestedBundle]
}

enum NestedBundleType: String, Sendable, CaseIterable {
    case framework
    case dynamicLibrary
    case appExtension
    case watchApp
    case watchExtension
    case nestedApp
    case helperExecutable
    case unknown
}
