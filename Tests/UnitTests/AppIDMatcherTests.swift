import XCTest
@testable import SignFlow

final class AppIDMatcherTests: XCTestCase {
    func testExactMatch() {
        XCTAssertTrue(AppIDMatcher.matchesBundleID("com.example.app", pattern: "com.example.app"))
        XCTAssertFalse(AppIDMatcher.matchesBundleID("com.example.other", pattern: "com.example.app"))
    }

    func testWildcardMatch() {
        XCTAssertTrue(AppIDMatcher.matchesBundleID("com.example.app", pattern: "com.example.*"))
        XCTAssertTrue(AppIDMatcher.matchesBundleID("com.example.app.share", pattern: "com.example.*"))
        XCTAssertTrue(AppIDMatcher.matchesBundleID("com.example", pattern: "com.example.*"))
        XCTAssertFalse(AppIDMatcher.matchesBundleID("com.other.app", pattern: "com.example.*"))
    }

    func testInvalidWildcardRejected() {
        XCTAssertFalse(AppIDMatcher.matchesBundleID("com.example.app", pattern: "com.*.app"))
        XCTAssertFalse(AppIDMatcher.matchesBundleID("com.example.app", pattern: "*example*"))
    }

    func testStarOnly() {
        XCTAssertTrue(AppIDMatcher.matchesBundleID("anything", pattern: "*"))
        XCTAssertFalse(AppIDMatcher.matchesBundleID("", pattern: "*"))
    }

    func testApplicationIdentifierWithTeam() {
        XCTAssertTrue(AppIDMatcher.matches(
            bundleIdentifier: "com.test.app",
            applicationIdentifier: "TEAMTEST1.com.test.app",
            teamPrefixes: ["TEAMTEST1"]
        ))
        XCTAssertTrue(AppIDMatcher.matches(
            bundleIdentifier: "com.test.app.share",
            applicationIdentifier: "TEAMTEST1.com.test.*",
            teamPrefixes: ["TEAMTEST1"]
        ))
        XCTAssertFalse(AppIDMatcher.matches(
            bundleIdentifier: "com.other.app",
            applicationIdentifier: "TEAMTEST1.com.test.app",
            teamPrefixes: ["TEAMTEST1"]
        ))
    }
}
