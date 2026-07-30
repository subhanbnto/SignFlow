import Foundation
import OSLog

/// Copies tweak payloads into the app bundle. Full Ellekit-style load-command rewriting
/// is experimental and reported clearly when unsupported.
struct TweakInjector: TweakInjecting {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "TweakInjector")

    func inject(tweakURLs: [URL], intoAppBundle appURL: URL, intoExtensions: Bool) async throws {
        try Task.checkCancellation()
        guard !tweakURLs.isEmpty else { return }

        let frameworks = appURL.appendingPathComponent("Frameworks", isDirectory: true)
        try FileManager.default.createDirectory(at: frameworks, withIntermediateDirectories: true)

        for tweakURL in tweakURLs {
            try Task.checkCancellation()
            let ext = tweakURL.pathExtension.lowercased()
            switch ext {
            case "dylib":
                let destination = frameworks.appendingPathComponent(tweakURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: tweakURL, to: destination)
                Self.logger.info("Copied dylib tweak \(tweakURL.lastPathComponent, privacy: .public)")
            case "deb":
                try extractDeb(at: tweakURL, into: frameworks)
            default:
                throw SignFlowError.signingFailed(
                    detail: "Unsupported tweak type .\(ext). Import a .dylib or .deb file."
                )
            }
        }

        if intoExtensions {
            let plugins = appURL.appendingPathComponent("PlugIns", isDirectory: true)
            if let items = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil) {
                for appex in items where appex.pathExtension == "appex" {
                    let appexFrameworks = appex.appendingPathComponent("Frameworks", isDirectory: true)
                    try FileManager.default.createDirectory(at: appexFrameworks, withIntermediateDirectories: true)
                    for tweakURL in tweakURLs where tweakURL.pathExtension.lowercased() == "dylib" {
                        let destination = appexFrameworks.appendingPathComponent(tweakURL.lastPathComponent)
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.copyItem(at: tweakURL, to: destination)
                    }
                }
            }
        }

        // Document limitation: without Mach-O load-command patching, dylibs must be
        // referenced by the target binary. We stage files for user-provided injectors.
        Self.logger.notice("Tweaks staged in Frameworks; load-command injection is experimental.")
    }

    private func extractDeb(at url: URL, into frameworks: URL) throws {
        // .deb is an ar archive containing data.tar.*; full ar parsing is deferred.
        // For now, reject with a clear resolution so the UI stays honest.
        throw SignFlowError.signingFailed(
            detail: "Direct .deb injection is not fully implemented yet. Convert the package to a .dylib and try again."
        )
    }
}
