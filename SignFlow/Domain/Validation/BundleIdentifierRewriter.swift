import Foundation

struct BundleIdentifierRewriter: BundleIdentifierRewriting {
    func computeMappings(
        original: String,
        replacement: String,
        nestedBundles: [NestedBundle]
    ) -> [BundleIDMapping] {
        var mappings: [BundleIDMapping] = [
            BundleIDMapping(original: original, replacement: replacement, componentPath: nil, isPrimary: true)
        ]

        guard original != replacement else {
            // Still map nested 1:1 for preview clarity when no change
            for nested in nestedBundles {
                mappings.append(BundleIDMapping(
                    original: nested.bundleIdentifier,
                    replacement: nested.bundleIdentifier,
                    componentPath: nested.relativePath,
                    isPrimary: false
                ))
            }
            return mappings
        }

        for nested in nestedBundles {
            let newID = rewriteNested(originalMain: original, newMain: replacement, nestedID: nested.bundleIdentifier)
            mappings.append(BundleIDMapping(
                original: nested.bundleIdentifier,
                replacement: newID,
                componentPath: nested.relativePath,
                isPrimary: false
            ))
        }

        return mappings
    }

    func rewriteNested(originalMain: String, newMain: String, nestedID: String) -> String {
        if nestedID == originalMain {
            return newMain
        }
        if nestedID.hasPrefix(originalMain + ".") {
            let suffix = nestedID.dropFirst(originalMain.count)
            return newMain + suffix
        }
        // Deterministic fallback: replace longest matching prefix segment
        return nestedID.replacingOccurrences(of: originalMain, with: newMain)
    }

    func applyMappings(mappings: [BundleIDMapping], toAppBundle appURL: URL) async throws {
        try Task.checkCancellation()

        for mapping in mappings where mapping.original != mapping.replacement {
            try Task.checkCancellation()
            let targetURL: URL
            if let relative = mapping.componentPath {
                targetURL = appURL.appendingPathComponent(relative)
            } else {
                targetURL = appURL
            }

            let infoURL = infoPlistURL(for: targetURL)
            guard FileManager.default.fileExists(atPath: infoURL.path) else { continue }

            let data = try Data(contentsOf: infoURL)
            guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                throw SignFlowError.malformedInfoPlist(detail: "Could not update bundle ID at \(infoURL.lastPathComponent).")
            }
            plist["CFBundleIdentifier"] = mapping.replacement
            let output = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try output.write(to: infoURL, options: .atomic)
        }
    }

    private func infoPlistURL(for bundleOrExecutable: URL) -> URL {
        if bundleOrExecutable.pathExtension == "framework"
            || bundleOrExecutable.pathExtension == "appex"
            || bundleOrExecutable.pathExtension == "app" {
            return bundleOrExecutable.appendingPathComponent("Info.plist")
        }
        return bundleOrExecutable.appendingPathComponent("Info.plist")
    }
}
