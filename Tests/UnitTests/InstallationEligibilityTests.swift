import XCTest
@testable import SignFlow

final class InstallationEligibilityTests: XCTestCase {
    func testAdHocUsesHostedOTA() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .adHoc, accountPlan: .paid)
        guard case .hostedOTA = eligibility else {
            return XCTFail("Expected hosted OTA for Ad Hoc")
        }
    }

    func testEnterpriseUsesHostedOTA() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .enterprise, accountPlan: .paid)
        guard case .hostedOTA = eligibility else {
            return XCTFail("Expected hosted OTA for Enterprise")
        }
    }

    func testDevelopmentUsesHostedOTA() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .development, accountPlan: .free)
        guard case .hostedOTA = eligibility else {
            return XCTFail("Expected hosted OTA for development profiles")
        }
    }

    func testAppStoreUnavailable() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .appStore, accountPlan: .paid)
        guard case .unavailable = eligibility else {
            return XCTFail("Expected unavailable for App Store profiles")
        }
    }

    func testUnknownFreeUsesExternalHandoff() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .unknown, accountPlan: .free)
        guard case .externalHandoff = eligibility else {
            return XCTFail("Expected external handoff for free/unknown")
        }
    }
}
