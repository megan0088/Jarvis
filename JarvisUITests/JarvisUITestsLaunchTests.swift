//
//  JarvisUITestsLaunchTests.swift
//  JarvisUITests
//
//  Created by Muhamad Ega Nugraha on 13/03/26.
//

import XCTest

final class JarvisUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        #if os(macOS)
        throw XCTSkip("macOS UI launch tests require Accessibility permission for screenshots and appearance changes.")
        #else
        continueAfterFailure = false
        #endif
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
