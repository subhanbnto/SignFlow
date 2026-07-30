import Foundation
import UIKit
import OSLog

actor HostedOTAInstaller: AppInstalling {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "HostedOTAInstaller")
    private static let partSize = 5 * 1024 * 1024

    private let tokenStore: InstallerAPITokenStore
    private let session: URLSession
    private let accountPlan: @Sendable () -> DeveloperAccountPlan

    init(
        tokenStore: InstallerAPITokenStore = InstallerAPITokenStore(),
        session: URLSession = .shared,
        accountPlan: @escaping @Sendable () -> DeveloperAccountPlan = {
            DeveloperAccountPlan(
                rawValue: UserDefaults.standard.string(forKey: "developerAccountPlan") ?? ""
            ) ?? .free
        }
    ) {
        self.tokenStore = tokenStore
        self.session = session
        self.accountPlan = accountPlan
    }

    var isAvailable: Bool {
        get async {
            guard InstallerSettings.endpointURL != nil else { return false }
            return (try? await tokenStore.hasToken()) == true
        }
    }

    var unavailableReason: String? {
        get async {
            if await isAvailable { return nil }
            return SignFlowError.installationNotConfigured.explanation
        }
    }

    func eligibility(for request: InstallationRequest) async -> InstallationEligibility {
        InstallationEligibilityEvaluator.evaluate(
            profileType: request.profileType,
            accountPlan: accountPlan()
        )
    }

    func testConnection() async throws -> String {
        let baseURL = try requireBaseURL()
        let token = try await requireToken()
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response, data: data, context: "health check")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let service = json["service"] as? String {
            let hours = json["retentionHours"] as? Int ?? 6
            return "Connected to \(service). Temporary uploads are retained for about \(hours) hour(s)."
        }
        return "Installer backend is reachable."
    }

    func install(
        request: InstallationRequest,
        progressHandler: @escaping @Sendable (InstallationProgress) -> Void
    ) async throws -> InstallationResult {
        let eligibility = await eligibility(for: request)
        switch eligibility {
        case .hostedOTA:
            return try await performOTA(request: request, progressHandler: progressHandler)
        case .externalHandoff(let reason):
            progressHandler(InstallationProgress(stage: .complete, fractionCompleted: 1, message: reason))
            return InstallationResult(
                kind: .externalShare,
                message: reason,
                installURL: nil,
                manifestURL: nil,
                expiresAt: nil
            )
        case .unavailable(let reason):
            throw SignFlowError.installationIneligible(reason: reason)
        }
    }

    // MARK: - OTA upload

    private func performOTA(
        request: InstallationRequest,
        progressHandler: @escaping @Sendable (InstallationProgress) -> Void
    ) async throws -> InstallationResult {
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: request.ipaURL.path) else {
            throw SignFlowError.installationFailed(detail: "Signed IPA is no longer available on disk.")
        }
        guard InstallerSettings.retentionAcknowledged else {
            throw SignFlowError.installationFailed(
                detail: "Acknowledge temporary HTTPS upload retention in Settings before installing."
            )
        }

        let baseURL = try requireBaseURL()
        let token = try await requireToken()
        let partCount = max(1, Int((request.byteSize + UInt64(Self.partSize) - 1) / UInt64(Self.partSize)))

        progressHandler(InstallationProgress(stage: .preparing, fractionCompleted: 0.02, message: "Creating upload session"))

        let createURL = baseURL.appendingPathComponent("v1/releases")
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "bundleIdentifier": request.bundleIdentifier,
            "bundleVersion": request.bundleVersion,
            "title": request.displayName,
            "sha256": request.outputSHA256.lowercased(),
            "byteSize": request.byteSize,
            "partCount": partCount
        ])

        let (createData, createResponse) = try await session.data(for: createRequest)
        try validateHTTP(createResponse, data: createData, context: "create release")
        let created = try decodeJSON(createData)
        guard let releaseId = created["releaseId"] as? String else {
            throw SignFlowError.installationFailed(detail: "Installer did not return a release ID.")
        }

        let handle = try FileHandle(forReadingFrom: request.ipaURL)
        defer { try? handle.close() }

        for partNumber in 1...partCount {
            try Task.checkCancellation()
            let data = try handle.read(upToCount: Self.partSize) ?? Data()
            guard !data.isEmpty else {
                throw SignFlowError.installationFailed(detail: "Unexpected end of IPA while uploading part \(partNumber).")
            }

            let partURL = baseURL
                .appendingPathComponent("v1/releases/\(releaseId)/parts/\(partNumber)")
            var partRequest = URLRequest(url: partURL)
            partRequest.httpMethod = "PUT"
            partRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            partRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            partRequest.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
            partRequest.httpBody = data

            let (partData, partResponse) = try await session.data(for: partRequest)
            try validateHTTP(partResponse, data: partData, context: "upload part \(partNumber)")

            let fraction = 0.05 + (0.8 * (Double(partNumber) / Double(partCount)))
            progressHandler(
                InstallationProgress(
                    stage: .uploading,
                    fractionCompleted: fraction,
                    message: "Uploading part \(partNumber) of \(partCount)"
                )
            )
        }

        progressHandler(InstallationProgress(stage: .finalizing, fractionCompleted: 0.9, message: "Finalizing release"))

        let completeURL = baseURL.appendingPathComponent("v1/releases/\(releaseId)/complete")
        var completeRequest = URLRequest(url: completeURL)
        completeRequest.httpMethod = "POST"
        completeRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (completeData, completeResponse) = try await session.data(for: completeRequest)
        try validateHTTP(completeResponse, data: completeData, context: "complete release")
        let completed = try decodeJSON(completeData)

        guard let installURLString = completed["installURL"] as? String,
              let installURL = URL(string: installURLString) else {
            throw SignFlowError.installationFailed(detail: "Installer did not return an install URL.")
        }
        let manifestURL = (completed["manifestURL"] as? String).flatMap(URL.init(string:))
        let expiresAt = (completed["expiresAt"] as? String).flatMap(Self.parseISO8601)

        progressHandler(InstallationProgress(stage: .handingOff, fractionCompleted: 0.97, message: "Opening iOS installer"))
        try await openInstallURL(installURL)
        progressHandler(InstallationProgress(stage: .complete, fractionCompleted: 1, message: "Installation handoff started"))

        return InstallationResult(
            kind: .otaHandoff,
            message: "iOS should prompt to install \(request.displayName). After installation, trust the developer certificate in Settings if prompted.",
            installURL: installURL,
            manifestURL: manifestURL,
            expiresAt: expiresAt
        )
    }

    // MARK: - Helpers

    private func requireBaseURL() throws -> URL {
        guard let url = InstallerSettings.endpointURL else {
            throw SignFlowError.installationNotConfigured
        }
        return url
    }

    private func requireToken() async throws -> String {
        guard let token = try await tokenStore.load(), !token.isEmpty else {
            throw SignFlowError.installationNotConfigured
        }
        return token
    }

    private func validateHTTP(_ response: URLResponse, data: Data, context: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SignFlowError.installationFailed(detail: "Invalid response during \(context).")
        }
        guard (200...299).contains(http.statusCode) else {
            let serverMessage = (try? decodeJSON(data)["error"] as? String) ?? String(data: data, encoding: .utf8)
            let detail = serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SignFlowError.installationFailed(
                detail: "\(context.capitalized) failed (\(http.statusCode)). \(detail ?? "")".trimmingCharacters(in: .whitespaces)
            )
        }
    }

    private func decodeJSON(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SignFlowError.installationFailed(detail: "Installer returned a malformed JSON payload.")
        }
        return object
    }

    @MainActor
    private func openInstallURLOnMain(_ url: URL) async throws {
        guard UIApplication.shared.canOpenURL(url) || url.scheme == "itms-services" else {
            throw SignFlowError.installationFailed(detail: "This device cannot open itms-services installation links.")
        }
        let opened = await UIApplication.shared.open(url, options: [:])
        if !opened {
            Self.logger.error("UIApplication.open returned false for install URL")
            // Still treat as handoff attempted; iOS sometimes reports false for itms-services.
        }
    }

    private func openInstallURL(_ url: URL) async throws {
        try await openInstallURLOnMain(url)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
