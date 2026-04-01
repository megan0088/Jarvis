//
//  JarvisUITests.swift
//  JarvisUITests
//
//  Created by Muhamad Ega Nugraha on 13/03/26.
//

import XCTest

final class JarvisUITests: XCTestCase {

    override func setUpWithError() throws {
        #if os(macOS)
        throw XCTSkip("macOS UI tests require Accessibility permission for UI automation in this environment.")
        #else
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        #endif
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        #if os(macOS)
        throw XCTSkip("macOS launch performance UI test requires Accessibility permission.")
        #else
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
        #endif
    }
}
