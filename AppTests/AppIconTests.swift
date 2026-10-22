import XCTest
import UIKit
@testable import SimplyKANA

/// The asset catalog compiled into the app: an icon (not the blank default)
/// and the paper launch colour (not a white flash).
final class AppIconTests: XCTestCase {
    /// Tests are hosted by the app, so the main bundle is the app.
    private var app: Bundle { Bundle.main }

    func testAppHasCompiledIcon() throws {
        let icons = try XCTUnwrap(app.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
                                  "no CFBundleIcons: the icon did not compile into the app")
        let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
        XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIcon")
    }

    func testLaunchScreenIsPaper() throws {
        let launch = try XCTUnwrap(app.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any])
        XCTAssertEqual(launch["UIColorName"] as? String, "LaunchPaper")
        XCTAssertNotNil(UIColor(named: "LaunchPaper", in: app, compatibleWith: nil), "LaunchPaper colour missing")
    }
}
