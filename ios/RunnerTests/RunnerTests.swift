import XCTest

@testable import Runner

/// KAN-1006: the activity_ended reason mapping (LiveActivityPlugin.endedEvent).
class RunnerTests: XCTestCase {
  typealias P = LiveActivityPlugin

  func testAppEndEmitsNothingAndIsRemembered() {
    let r = P.endedEvent(.ended, prior: nil, endedByApp: true)
    XCTAssertNil(r.reason)
    XCTAssertEqual(r.outcome, .byApp)
    let d = P.endedEvent(.dismissed, prior: .byApp, endedByApp: true)
    XCTAssertNil(d.reason)
  }

  func testExternalEndIsSystemThenDismissalIsExpired() {
    let r = P.endedEvent(.ended, prior: nil, endedByApp: false)
    XCTAssertEqual(r.reason, "system")
    XCTAssertEqual(r.outcome, .external)
    let d = P.endedEvent(.dismissed, prior: .external, endedByApp: false)
    XCTAssertEqual(d.reason, "expired")
  }

  func testDismissWhileActiveIsUserDismissed() {
    XCTAssertEqual(P.endedEvent(.dismissed, prior: nil, endedByApp: false).reason, "user_dismissed")
    XCTAssertNil(P.endedEvent(.dismissed, prior: nil, endedByApp: true).reason)
  }

  func testRepeatedEndedEmitsOnce() {
    XCTAssertNil(P.endedEvent(.ended, prior: .external, endedByApp: false).reason)
    XCTAssertNil(P.endedEvent(.ended, prior: .byApp, endedByApp: true).reason)
  }

  func testVersionRule() {
    XCTAssertTrue(P.shouldApply(held: nil, incoming: 1))
    XCTAssertFalse(P.shouldApply(held: 2, incoming: 2))
    XCTAssertTrue(P.shouldApply(held: 2, incoming: 3))
  }
}
