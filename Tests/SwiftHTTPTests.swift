//
//  SwiftHTTPTests.swift
//  SwiftHTTPTests
//
//  Created by Austin Cherry on 9/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//

import XCTest
#if os(iOS)
    import SwiftHTTP
    #elseif os(OSX)
    import SwiftHTTPOSX
#endif

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
        var request = HTTPTask()
        request.GET("http://vluxe.io", parameters: nil, success: {(response: HTTPResponse) -> Void in
            if response.responseObject != nil {
                XCTAssert(true, "Pass")
            }
            },failure: {(error: NSError) -> Void in
                XCTAssert(false, "Failure")
        })
    }
    
    func testAuthRequest() {
        var request = HTTPTask()
        request.auth = HTTPAuth(username: "user", password: "passwd")
        request.GET("http://httpbin.org/basic-auth/user/passwd", parameters: nil, success: {(response: HTTPResponse) -> Void in
            if response.responseObject != nil {
                XCTAssert(true, "Pass")
            }
            },failure: {(error: NSError) -> Void in
                XCTAssert(false, "Failure")
        })
    }
}
