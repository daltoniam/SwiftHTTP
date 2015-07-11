//
//  SwiftHTTPTestsWithOHHTTPStubs.swift
//  SwiftHTTP
//
//  Created by 比佐 幸基 on 2015/07/11.
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

        let prot = "http"
        let host = "example.com"
        let opt = ""
        let url = "\(prot)://\(host)/\(opt)"

        func getHelloWorld() -> String {
            return "Hello World!"
        }

        func responseGET(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }
        func responsePOST(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }
        func responsePUT(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }
        func responseHEAD(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }
        func responseDELETE(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }
        func responsePATCH(request: NSURLRequest) -> OHHTTPStubsResponse {
            return OHHTTPStubsResponse()
        }

        OHHTTPStubs.stubRequestsPassingTest({(request: NSURLRequest)  in
            println(request.URL!.host)
            return request.URL!.host == host
            }, withStubResponse: {(request: NSURLRequest) in
                let requestMethods = HTTPMethod(rawValue: request.HTTPMethod!)!
                switch requestMethods {
                case .GET:
                    return responseGET(request)
                case .POST:
                    return responsePOST(request)
                case .PUT:
                    return responsePUT(request)
                case .HEAD:
                    return responseHEAD(request)
                case .DELETE:
                    return responseDELETE(request)
                case .PATCH:
                    return responsePATCH(request)
                default:
                    let stubData = getHelloWorld().dataUsingEncoding(NSUTF8StringEncoding)
                    return OHHTTPStubsResponse(data: stubData!, statusCode:200, headers:nil)
                }
        })


        let request = HTTPTask()
        request.GET(url, parameters: nil, completionHandler: {(response: HTTPResponse)  in
            if let err = response.error {
                XCTAssert(false, "Failure")
            }

            if let data = response.responseObject as? NSData {
                let str = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("response: \(str)") //prints the HTML of the page
            }
            
            XCTAssert(true, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }

}
