//
//  SwiftHTTPTests.swift
//  SwiftHTTPTests
//
//  Created by Austin Cherry on 9/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//

import XCTest
import SwiftHTTP
import OHHTTPStubs

class SwiftHTTPTests: XCTestCase {
    
    let kTimeout: NSTimeInterval = 1
    let kDummyURL = "example.com"

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
        
        OHHTTPStubs.stubRequestsPassingTest({(request: NSURLRequest) in
                return true
            }, withStubResponse: {(request: NSURLRequest) in
                let responseHTML = "<html><head></head><body></body></html>"
                let responseData = responseHTML.dataUsingEncoding(NSUTF8StringEncoding)
                return OHHTTPStubsResponse(data: responseData!, statusCode:200, headers:nil)
            }
        )
        
        let request = HTTPTask()
        request.GET(kDummyURL, parameters: nil, completionHandler: {(response: HTTPResponse)  in
            if let err = response.error {
                XCTAssert(false, "Failure")
            }
            XCTAssert(true, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(kTimeout, handler: nil)
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
        request.GET("http://httpbin.org/basic-auth/user/passwd", parameters: nil, completionHandler: {(response: HTTPResponse) in
            if let err = response.error {
                XCTAssert(false, "Failure")
            }
            XCTAssert(true, "Pass")
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
        
        OHHTTPStubs.stubRequestsPassingTest({(request: NSURLRequest) in
            return true
            }, withStubResponse: {(request: NSURLRequest) in
                let err = NSError(domain: "testOperationDependencies", code: 400, userInfo: [NSLocalizedDescriptionKey: "Requested URL is not urlString"])
                var response = OHHTTPStubsResponse(error: err)
                if request.URL!.absoluteString == urlString1 {
                    let responseData = "PIA19330.tif".dataUsingEncoding(NSUTF8StringEncoding)
                    response =  OHHTTPStubsResponse(data: responseData!, statusCode:200, headers:nil).requestTime(0.0, responseTime: 0.5)
                }
                
                if request.URL!.absoluteString == urlString2 {
                    let responseData = "PIA19330.jpg".dataUsingEncoding(NSUTF8StringEncoding)
                    response =  OHHTTPStubsResponse(data: responseData!, statusCode:200, headers:nil).requestTime(0.0, responseTime: 0.1)
                }
                
                return response
            }
        )
        
        let request1 = HTTPTask()
        let op1 = request1.create(urlString1, method: .GET, parameters: nil, completionHandler: { (response) -> Void in
            if let err = response.error {
                XCTFail("request1 failed: \(err.localizedDescription)")
            }
            operation1Finished = true
            expectation1.fulfill()
        })
        
        let request2 = HTTPTask()
        let op2 = request2.create(urlString2, method: .GET, parameters: nil, completionHandler: { (response) -> Void in
            if let err = response.error {
                XCTFail("request2 failed: \(err.localizedDescription)")
            }
            XCTAssert(operation1Finished, "Operation 1 did not finish first")
            expectation2.fulfill()
        })
        
        op2?.addDependency(op1!)
        operationQueue.addOperation(op1!)
        operationQueue.addOperation(op2!)
        
        waitForExpectationsWithTimeout(kTimeout, handler: nil)
    }
}
