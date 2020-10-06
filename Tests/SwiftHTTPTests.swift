//
//  SwiftHTTPTests.swift
//  SwiftHTTPTests
//
//  Created by Austin Cherry on 9/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//

import XCTest
import SwiftHTTP

class SwiftHTTPTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetRequest() throws {
        let expectation = self.expectation(description: "testGetRequest")
        
        do {
            let opt = try XCTUnwrap(HTTP.GET("https://google.com", parameters: nil))
            opt.run { response in
                if response.error != nil {
                    XCTAssert(false, "Failure")
                }
                XCTAssert(true, "Pass")
                expectation.fulfill()
            }
        } catch {
            XCTAssert(false, "Failure")
        }
        waitForExpectations(timeout: 30, handler: nil)
    }
	
	func testGetProgress() throws {
		let expectation1 = expectation(description: "testGetProgressFinished")
		let expectation2 = expectation(description: "testGetProgressIncremented")

		do {
			let opt = try XCTUnwrap(HTTP.GET("http://photojournal.jpl.nasa.gov/tiff/PIA19330.tif", parameters: nil))
			var alreadyCheckedProgressIncremented: Bool = false
			opt.progress = { progress in
				if progress > 0 && !alreadyCheckedProgressIncremented {
					alreadyCheckedProgressIncremented = true
					XCTAssert(true, "Pass")
					expectation2.fulfill()
				}
			}
			opt.run { response in
				if response.error != nil {
					XCTAssert(false, "Failure")
				}
				XCTAssert(true, "Pass")
				expectation1.fulfill()
			}
		} catch {
			XCTAssert(false, "Failure")
		}

		waitForExpectations(timeout: 30, handler: nil)
	}

}
