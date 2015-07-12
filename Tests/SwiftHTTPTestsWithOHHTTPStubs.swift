//
//  SwiftHTTPTestsWithOHHTTPStubs.swift
//  SwiftHTTP
//
//  Created by 比佐 幸基 on 2015/07/12.
//  Copyright (c) 2015年 Vluxe. All rights reserved.
//

import XCTest
import SwiftHTTP
import OHHTTPStubs

class SwiftHTTPTestsWithOHHTTPStubs: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testVirtualServerWithOHHTTPStubs() {
        let expectation = expectationWithDescription("testVirtualServerWithOHHTTPStubs")
        
        // setup OHHTTPStubs here.
        // Don't remove this code for preventing you from illegal HTTP access.
        self.setupOHHTTPStubs()
        
        let request = HTTPTask()
        
        let dummyURL = "dummyURL.com"
        request.GET(dummyURL, parameters: nil, completionHandler: {(response: HTTPResponse)  in
            if let err = response.error {
                XCTAssert(false, "Failure")
            }
            
            if let data = response.responseObject as? NSData {
                let str = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("response: \(str)")
            }
            
            XCTAssert(true, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    // setup OHHTPPStubs for running virtual API
    private func setupOHHTTPStubs() {
        OHHTTPStubs.stubRequestsPassingTest({(request: NSURLRequest) in
            // Put success request condition code here.
            // Now, all request is allowed.
            
            return true
            
            }, withStubResponse: {(request: NSURLRequest) in
                // Put creating response code here.
                // Now, here is a code for each request methods.
                
                let requestMethods = HTTPMethod(rawValue: request.HTTPMethod!)!
                switch requestMethods {
                case .GET:
                    return self.responseGET(request)
                case .POST:
                    return self.responsePOST(request)
                case .PUT:
                    return self.responsePUT(request)
                case .HEAD:
                    return self.responseHEAD(request)
                case .DELETE:
                    return self.responseDELETE(request)
                case .PATCH:
                    return self.responsePATCH(request)
                default:
                    return self.responseError(request)
                }
                
        })
    }
    
    // Samples of creating Response
    private func createHelloWorldResponse() -> OHHTTPStubsResponse {
        let stubData = "HelloWorld!".dataUsingEncoding(NSUTF8StringEncoding)
        return OHHTTPStubsResponse(data: stubData!, statusCode:200, headers:nil)
    }
    
    private func responseGET(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responsePOST(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responsePUT(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responseHEAD(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responseDELETE(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responsePATCH(request: NSURLRequest) -> OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse()
        return response
    }
    private func responseError(request: NSURLRequest) -> OHHTTPStubsResponse {
        let err = NSError(domain: "SwiftHTTPTestsWithOHHTTPStubs", code: 404, userInfo: nil)
        let response = OHHTTPStubsResponse(error: err)
        return response
    }
    
    
}
