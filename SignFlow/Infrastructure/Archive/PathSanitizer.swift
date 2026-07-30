import Foundation

enum PathSanitizer {
    static func validate(entryPath: String, relativeTo root: URL) throws -> URL {
        guard !entryPath.isEmpty else {
            throw SignFlowError.unsafeArchivePath(path: "(empty)")
        }

        let components = (entryPath as NSString).pathComponents
        var depth = 0
        for component in components {
            switch component {
            case ".":
                continue
            case "..":
                depth -= 1
                if depth < 0 {
                    throw SignFlowError.unsafeArchivePath(path: entryPath)
                }
            default:
                depth += 1
            }
        }

        let resolved = root.appendingPathComponent(entryPath).standardized
        guard resolved.path.hasPrefix(root.standardized.path) else {
            throw SignFlowError.unsafeArchivePath(path: entryPath)
        }

        return resolved
    }

    static func depthOf(_ url: URL, relativeTo root: URL) -> Int {
        url.pathComponents.count - root.pathComponents.count
    }
}
