//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPTask.swift
//
//  Created by Dalton Cherry on 6/3/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
}

class HTTPTask {
    
    var baseURL: String?
    var requestSerializer: HTTPRequestSerializer!
    var responseSerializer: HTTPResponseSerializer?
    
    init() {
    }
    
    ///main method that does the HTTP request. Called by GET,POST,PUT,DELETE,HEAD methods.
    func run(url: String,method: HTTPMethod,parameters: Dictionary<String,AnyObject>!, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) {
        
        var urlVal = url
        //probably should change the 'http' to something more generic
        if !url.hasPrefix("http") && self.baseURL {
            var split = url.hasPrefix("/") ? "" : "/"
            urlVal = "\(self.baseURL)\(split)\(url)"
        }
        if !self.requestSerializer {
            self.requestSerializer = HTTPRequestSerializer()
        }
        let serialReq = self.requestSerializer.createRequest(NSURL.URLWithString(urlVal),
            method: method, parameters: parameters)
        if serialReq.error {
            failure(serialReq.error!)
            return
        }
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(serialReq.request,
            completionHandler: {(data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if error {
                    failure(error)
                    return
                }
                if data {
                    var responseObject: AnyObject = data
                    if self.responseSerializer {
                        let resObj = self.responseSerializer!.responseObjectFromResponse(response, data: data)
                        if resObj.error {
                            failure(resObj.error!)
                            return
                        }
                        if resObj.object {
                            responseObject = resObj.object!
                        }
                    }
                    success(responseObject)
                } else {
                    failure(error)
                }
            })
        task.resume()
    }
    
    func GET(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        var task = HTTPTask()
        task.run(url,method: .GET,parameters: parameters,success,failure)
    }
    
    func POST(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        var task = HTTPTask()
        task.run(url,method: .POST,parameters: parameters,success,failure)
    }
    
    func PUT(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        var task = HTTPTask()
        task.run(url,method: .PUT,parameters: parameters,success,failure)
    }
    
    func DELETE(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        var task = HTTPTask()
        task.run(url,method: .DELETE,parameters: parameters,success,failure)
    }
    
    func HEAD(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        var task = HTTPTask()
        task.run(url,method: .DELETE,parameters: parameters,success,failure)
    }
   
}
