import XCTest
@testable import SignFlow

final class SignFlowErrorTests: XCTestCase {
    func testAllErrorsHaveTitleAndExplanation() {
        let errors: [SignFlowError] = [
            .invalidIPA(detail: "test"),
            .unsupportedArchive(detail: "test"),
            .archiveInputTooLarge(sizeBytes: 100, limitBytes: 50),
            .archiveExtractionLimitExceeded(limit: "count", actual: "200"),
            .unsafeArchivePath(path: "../bad"),
            .unsafeSymbolicLink(path: "link"),
            .missingPayloadDirectory,
            .multiplePayloadDirectories,
            .missingPrimaryApplication,
            .multiplePrimaryApplications(count: 3),
            .malformedInfoPlist(detail: "test"),
            .missingExecutable(name: "App"),
            .unsupportedMachO(detail: "test"),
            .userCancelled,
            .cleanupFailed(detail: "test"),
            .internalError(detail: "test"),
        ]

        for error in errors {
            XCTAssertFalse(error.title.isEmpty, "\(error) has empty title")
            XCTAssertFalse(error.explanation.isEmpty, "\(error) has empty explanation")
            XCTAssertFalse(error.suggestedResolution.isEmpty, "\(error) has empty resolution")
        }
    }
}
