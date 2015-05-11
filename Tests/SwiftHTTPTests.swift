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
    
    func testGetRequest() {
        let expectation = expectationWithDescription("testGetRequest")
        
        let request = HTTPTask()
        request.GET("http://vluxe.io", parameters: nil, success: {(response: HTTPResponse) -> Void in
            if response.responseObject != nil {
                XCTAssert(true, "Pass")
            }
            expectation.fulfill()
        },failure: {(error: NSError, _) -> Void in
            XCTAssert(false, "Failure")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testAuthRequest() {
        let expectation = expectationWithDescription("testAuthRequest")

        let request = HTTPTask()
        var attempted = false
        request.auth = {(challenge: NSURLAuthenticationChallenge) in
            if !attempted {
                attempted = true
                return NSURLCredential(user: "user", password: "passwd", persistence: .ForSession)
            }
            return nil
        }
        request.GET("http://httpbin.org/basic-auth/user/passwd", parameters: nil, success: {(response: HTTPResponse) -> Void in
            if response.responseObject != nil {
                XCTAssert(true, "Pass")
            }
            expectation.fulfill()
        },failure: {(error: NSError, _) -> Void in
            XCTAssert(false, "Failure")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testOperationDependencies() {
        let expectation1 = expectationWithDescription("testOperationDependencies1")
        let expectation2 = expectationWithDescription("testOperationDependencies2")
        
        let operationQueue = NSOperationQueue()
        operationQueue.maxConcurrentOperationCount = 2
        
        var operation1Finished = false
        
        let urlString1 = "http://photojournal.jpl.nasa.gov/tiff/PIA19330.tif" // (4.32 MB)
        let urlString2 = "http://photojournal.jpl.nasa.gov/jpeg/PIA19330.jpg" // (0.14 MB)
        
        let request1 = HTTPTask()
        let op1 = request1.create(urlString1, method: .GET, parameters: nil, success: { (response) -> Void in
            operation1Finished = true
            expectation1.fulfill()
        }) { (error, response) -> Void in
            operation1Finished = true
            XCTFail("request1 failed: \(error.localizedDescription)")
            expectation1.fulfill()
        }
        
        let request2 = HTTPTask()
        let op2 = request2.create(urlString2, method: .GET, parameters: nil, success: { (response) -> Void in
            XCTAssert(operation1Finished, "Operation 1 did not finish first")
            expectation2.fulfill()
        }) { (error, response) -> Void in
            XCTFail("request1 failed: \(error.localizedDescription)")
            XCTAssert(operation1Finished, "Operation 1 did not finish first")
            expectation2.fulfill()
        }
        
        op2?.addDependency(op1!)
        operationQueue.addOperation(op1!)
        operationQueue.addOperation(op2!)
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
}
