import SwiftUI

struct PreflightView: View {
    let configuration: SigningConfiguration
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var report: PreflightReport?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 18) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Running preflight")
                        .font(.headline)
                    Text("Checking identity, profile, App ID, devices, and entitlements.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
            } else if let report {
                List {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: report.canSign ? "checkmark.shield.fill" : "xmark.shield.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(report.canSign ? .green : .red)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(report.canSign ? "Ready to sign" : "Action required")
                                    .font(.title3.weight(.bold))
                                Text(report.canSign
                                     ? "\(report.warnings.count) warning\(report.warnings.count == 1 ? "" : "s") to review"
                                     : "\(report.fatalIssues.count) blocking issue\(report.fatalIssues.count == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            SignFlowStatusBadge(
                                text: report.canSign ? "Passed" : "Blocked",
                                kind: report.canSign ? .ready : .blocked
                            )
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Configuration") {
                        LabeledContent("App", value: report.packageSummary)
                        LabeledContent("Certificate", value: report.identitySummary)
                        LabeledContent("Profile", value: report.profileSummary)
                    }

                    if !report.bundleIdentifierMappings.isEmpty {
                        Section("Bundle ID Mapping") {
                            ForEach(report.bundleIdentifierMappings) { mapping in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mapping.isPrimary ? "Main App" : (mapping.componentPath ?? "Nested"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(mapping.original)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                    Text(mapping.replacement)
                                        .font(.subheadline.bold())
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    ForEach(report.entitlementReports) { entReport in
                        Section("Entitlements — \(entReport.bundleIdentifier)") {
                            if !entReport.keptKeys.isEmpty {
                                Text("Kept: \(entReport.keptKeys.joined(separator: ", "))")
                                    .font(.caption)
                            }
                            if !entReport.removedKeys.isEmpty {
                                Text("Removed: \(entReport.removedKeys.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if !report.fatalIssues.isEmpty {
                        Section("Blocking Issues") {
                            ForEach(report.fatalIssues) { issue in
                                issueRow(issue, color: .red)
                            }
                        }
                    }

                    if !report.warnings.isEmpty {
                        Section("Warnings") {
                            ForEach(report.warnings) { issue in
                                issueRow(issue, color: .orange)
                            }
                        }
                    }

                }
                .listStyle(.insetGrouped)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 7) {
                        SignFlowPrimaryButton(
                            title: "Sign App",
                            systemImage: "signature",
                            isDisabled: !report.canSign
                        ) {
                            router.navigate(to: .signingProgress(configuration))
                        }
                        if !report.canSign {
                            Text("Resolve all blocking issues before signing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .background(.ultraThinMaterial)
                }
            } else {
                ContentUnavailableView("Validation Failed", systemImage: "exclamationmark.triangle")
            }
        }
        .background(SignFlowTheme.background)
        .navigationTitle("Preflight")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            report = await environment.preflightValidator.validate(configuration: configuration)
            isLoading = false
        }
    }

    private func issueRow(_ issue: ValidationIssue, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(issue.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let resolution = issue.suggestedResolution {
                Text(resolution)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
