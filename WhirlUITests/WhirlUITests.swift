import XCTest

final class WhirlUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeFlowStartsOnFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-whirl.ui_testing",
            "-AppleLanguages", "(en)",
        ]
        app.launch()
        addTeardownBlock { app.terminate() }
        XCTAssertTrue(app.staticTexts["Welcome to Whirl"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue"].exists)
    }

    @MainActor
    func testPermissionGuidanceWhenPermissionsAreDenied() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-whirl.ui_testing",
            "-whirl.ui_testing.permissions_denied",
            "-AppleLanguages", "(en)",
        ]
        app.launch()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.staticTexts["Welcome to Whirl"].waitForExistence(timeout: 5))
        app.buttons["Continue"].click()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Authorize")).count, 1)
        XCTAssertTrue(app.buttons["Refresh permission status"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "turn it off and on again"
        )).firstMatch.exists)
    }

    @MainActor
    func testSettingsNavigationInEnglishAndBindingEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-whirl.ui_testing",
            "-whirl.ui_testing.skip_welcome",
            "-whirl.ui_testing.seed_bindings",
            "-AppleLanguages", "(en)",
        ]
        app.launch()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.staticTexts["General"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Hide Sidebar"].exists)
        XCTAssertTrue(app.staticTexts["Picker layout"].exists)
        XCTAssertTrue(app.popUpButtons["overlay.layout.picker"].exists)
        app.staticTexts["Shortcuts"].click()
        XCTAssertTrue(app.staticTexts["Alpha Notes"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Installed apps"].exists)
        XCTAssertTrue(app.staticTexts["Configured apps"].exists)
        XCTAssertTrue(app.buttons["bindings.choose_other"].exists)
        let alphaLibrary = app.staticTexts["library.name.com.example.alpha"]
        let betaLibrary = app.staticTexts["library.name.com.example.beta"]
        XCTAssertLessThan(alphaLibrary.frame.minY, betaLibrary.frame.minY)

        app.buttons["library.configure.com.example.gamma"].click()
        let pendingCancel = app.buttons["binding.pending.cancel"]
        XCTAssertTrue(pendingCancel.waitForExistence(timeout: 2))
        let keyCapture = app.otherElements["key.capture"]
        XCTAssertTrue(keyCapture.exists)
        pendingCancel.click()
        XCTAssertFalse(pendingCancel.waitForExistence(timeout: 1))

        let alphaDelete = app.buttons["binding.delete.com.example.alpha"]
        let betaDelete = app.buttons["binding.delete.com.example.beta"]
        XCTAssertLessThan(alphaDelete.frame.minY, betaDelete.frame.minY)
        app.images["binding.drag.com.example.alpha"].click(
            forDuration: 0.5,
            thenDragTo: app.images["binding.drag.com.example.beta"]
        )
        XCTAssertGreaterThan(alphaDelete.frame.minY, betaDelete.frame.minY)
        XCTAssertGreaterThan(alphaLibrary.frame.minY, betaLibrary.frame.minY)

        alphaDelete.click()
        XCTAssertFalse(alphaDelete.waitForExistence(timeout: 1))
        XCTAssertLessThan(betaLibrary.frame.minY, alphaLibrary.frame.minY)

        app.staticTexts["About"].click()
        XCTAssertTrue(app.staticTexts["baiyanwu"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsUseSimplifiedChinese() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-whirl.ui_testing",
            "-whirl.ui_testing.skip_welcome",
            "-AppleLanguages", "(zh-Hans)",
        ]
        app.launch()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.staticTexts["基础设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["快捷配置"].exists)
        XCTAssertTrue(app.staticTexts["关于"].exists)
        XCTAssertTrue(app.staticTexts["包含应用标签页"].exists)
        XCTAssertTrue(app.staticTexts["切换布局"].exists)
    }
}
