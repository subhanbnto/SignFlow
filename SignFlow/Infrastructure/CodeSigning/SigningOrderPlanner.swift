import Foundation

struct SigningOrderPlanner: SigningOrderPlanning {
    func planSigningOrder(appURL: URL, nestedBundles: [NestedBundle]) -> [SigningUnit] {
        var units: [SigningUnit] = []
        var order = 0

        func append(_ url: URL, kind: NestedBundleType, relative: String, bundleID: String?) {
            units.append(SigningUnit(
                path: url,
                relativePath: relative,
                kind: kind,
                order: order,
                bundleIdentifier: bundleID
            ))
            order += 1
        }

        // Bottom-up priority
        let prioritized = nestedBundles.sorted { lhs, rhs in
            priority(lhs.type) < priority(rhs.type)
        }

        for nested in prioritized {
            let url = appURL.appendingPathComponent(nested.relativePath)
            let signTarget: URL
            if nested.type == .dynamicLibrary || nested.type == .helperExecutable {
                signTarget = url
            } else {
                // Prefer bundle executable if present
                let execName = nested.executableName
                if let execName {
                    let execURL = url.appendingPathComponent(execName)
                    signTarget = FileManager.default.fileExists(atPath: execURL.path) ? url : url
                } else {
                    signTarget = url
                }
            }
            _ = signTarget
            append(url, kind: nested.type, relative: nested.relativePath, bundleID: nested.bundleIdentifier)
        }

        append(appURL, kind: .nestedApp, relative: ".", bundleID: nil)
        return units
    }

    private func priority(_ type: NestedBundleType) -> Int {
        switch type {
        case .dynamicLibrary: return 0
        case .framework: return 1
        case .helperExecutable: return 2
        case .appExtension, .watchExtension: return 3
        case .watchApp: return 4
        case .nestedApp: return 5
        case .unknown: return 6
        }
    }
}
