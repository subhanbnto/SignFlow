import SwiftUI

struct AppInspectorView: View {
    let package: AppPackage
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(SignFlowTheme.accent)
                        .frame(width: 62, height: 62)
                        .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.displayName)
                            .font(.title3.weight(.bold))
                        Text(package.primaryBundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 7) {
                            SignFlowStatusBadge(
                                text: "v\(package.version)",
                                kind: .neutral
                            )
                            SignFlowStatusBadge(
                                text: package.existingSignatureStatus.rawValue.capitalized,
                                kind: package.existingSignatureStatus == .invalid ? .blocked : .neutral
                            )
                        }
                    }
                }
                .padding(.vertical, 8)

                Button {
                    router.navigate(to: .signingSetup)
                } label: {
                    Label("Sign This App", systemImage: "signature")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(SignFlowTheme.accent)
            }

            Section("Application") {
                row("Display Name", package.displayName)
                row("Bundle Identifier", package.primaryBundleIdentifier)
                row("Version", "\(package.version) (\(package.buildNumber))")
                row("Minimum iOS", package.minimumOSVersion)
                row("Executable", package.executableName)
            }

            Section("File") {
                row("Filename", package.originalFilename)
                row("Size", ByteCountFormatter.string(fromByteCount: Int64(package.fileSize), countStyle: .file))
                row("SHA-256", package.sha256)
            }

            Section("Architecture") {
                ForEach(package.architectures, id: \.self) { arch in
                    Label(arch.rawValue, systemImage: "cpu")
                }
            }

            Section("Signature") {
                row("Status", package.existingSignatureStatus.rawValue.capitalized)
                row("Embedded Profile", package.embeddedProvisioningProfile ? "Present" : "None")
            }

            if !package.nestedBundles.isEmpty {
                Section("Nested Components (\(package.nestedBundles.count))") {
                    ForEach(package.nestedBundles) { nested in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(nested.bundleIdentifier, systemImage: iconFor(nested.type))
                                .font(.subheadline.bold())
                            Text(nested.relativePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(nested.type.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !package.inspectionWarnings.isEmpty {
                Section("Warnings") {
                    ForEach(package.inspectionWarnings) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(issue.title, systemImage: iconFor(issue.severity))
                                .font(.subheadline.bold())
                                .foregroundStyle(colorFor(issue.severity))
                            Text(issue.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(package.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func iconFor(_ type: NestedBundleType) -> String {
        switch type {
        case .framework:       return "shippingbox"
        case .dynamicLibrary:  return "link"
        case .appExtension:    return "puzzlepiece.extension"
        case .watchApp:        return "applewatch"
        case .watchExtension:  return "applewatch.side.right"
        case .nestedApp:       return "app"
        case .helperExecutable: return "terminal"
        case .unknown:         return "questionmark.circle"
        }
    }

    private func iconFor(_ severity: ValidationIssue.Severity) -> String {
        switch severity {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .fatal:   return "xmark.octagon"
        }
    }

    private func colorFor(_ severity: ValidationIssue.Severity) -> Color {
        switch severity {
        case .info:    return .blue
        case .warning: return .orange
        case .fatal:   return .red
        }
    }
}
