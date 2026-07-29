import XCTest
@testable import SignFlow

final class ArchiveLimitsTests: XCTestCase {
    func testDefaultLimitsAreReasonable() {
        let limits = ArchiveLimits.default
        XCTAssertGreaterThan(limits.maxCompressedSize, 0)
        XCTAssertGreaterThan(limits.maxExtractedSize, limits.maxCompressedSize)
        XCTAssertGreaterThan(limits.maxEntryCount, 0)
        XCTAssertGreaterThan(limits.maxDirectoryDepth, 0)
        XCTAssertGreaterThan(limits.maxCompressionRatio, 1.0)
    }
}
