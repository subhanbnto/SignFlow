import Foundation
import UserNotifications
import OSLog

/// Abstraction for scheduling local notifications about certificate/profile expiration.
/// Does not claim delivery — only requests authorization and schedules when permitted.
actor LocalExpirationNotifier: ExpirationNotifying {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ExpirationNotifier")
    private static let category = "signflow.expiration"

    func scheduleExpirationWarnings(
        for identities: [SigningIdentity],
        profiles: [ProvisioningProfile]
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional else {
            Self.logger.info("Notifications not authorized; skipping expiration scheduling")
            return
        }

        await cancelAllWarnings()

        for identity in identities where identity.isExpiringSoon || identity.isExpired {
            await schedule(
                id: "cert-\(identity.id.uuidString)",
                title: identity.isExpired ? "Certificate Expired" : "Certificate Expiring Soon",
                body: "\(identity.displayName) \(identity.isExpired ? "has expired" : "expires in \(identity.daysRemaining) days")."
            )
        }

        for profile in profiles where profile.isExpiringSoon || profile.isExpired {
            await schedule(
                id: "profile-\(profile.id.uuidString)",
                title: profile.isExpired ? "Profile Expired" : "Profile Expiring Soon",
                body: "\(profile.name) \(profile.isExpired ? "has expired" : "expires in \(profile.daysRemaining) days")."
            )
        }
    }

    func cancelAllWarnings() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        Self.logger.info("Cancelled pending expiration notifications")
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Self.logger.error("Notification authorization failed")
            return false
        }
    }

    private func schedule(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Self.category

        // Fire shortly after scheduling for awareness; production would use expiry-relative triggers
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Self.logger.error("Failed to schedule notification \(id, privacy: .public)")
        }
    }
}
