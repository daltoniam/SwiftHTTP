//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPTask.swift
//
//  Created by Dalton Cherry on 6/3/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

//this should go away at some point. Just a work around for poor swift substring support
//http://openradar.appspot.com/radar?id=6373877630369792
extension String {
    
    subscript (idx: Int) -> String
        {
        get
        {
            return self.substringWithRange(
                Range( start: advance( self.startIndex, idx),
                    end: advance( self.startIndex, idx + 1 )  )
            )
        }
    }
    
    subscript (r: Range<Int>) -> String
        {
        get
        {
            return self.substringWithRange(
                Range( start: advance( self.startIndex, r.startIndex),
                    end: advance( self.startIndex, r.endIndex + 1 ))              )
        }
    }
    
    func substringFrom(start: Int, to: Int) -> String
    {
        return (self.substringFromIndex(start)).substringToIndex(to - start + 1)
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
}

class HTTPTask : NSObject, NSURLSessionDelegate {
    
    var baseURL: String?
    var requestSerializer: HTTPRequestSerializer!
    var responseSerializer: HTTPResponseSerializer?
    
    init() {
    }
    
    ///main method that does the HTTP request. Called by GET,POST,PUT,DELETE,HEAD methods.
    func run(url: String,method: HTTPMethod,parameters: Dictionary<String,AnyObject>!, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) {
        
        let serialReq = createRequest(url,method: method, parameters: parameters)
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
    func createRequest(url: String,method: HTTPMethod,parameters: Dictionary<String,AnyObject>!) -> (request: NSURLRequest, error: NSError?) {
        var urlVal = url
        //probably should change the 'http' to something more generic
        if !url.hasPrefix("http") && self.baseURL {
            var split = url.hasPrefix("/") ? "" : "/"
            urlVal = "\(self.baseURL)\(split)\(url)"
        }
        if !self.requestSerializer {
            self.requestSerializer = HTTPRequestSerializer()
        }
        return self.requestSerializer.createRequest(NSURL.URLWithString(urlVal),
            method: method, parameters: parameters)
        
    }
    //creates a random string to use for the identifer of the background download/upload requests
    func createBackgroundIdent() -> String {
        let letters = "abcdefghijklmnopqurstuvwxyz"
        var str = ""
        for var i = 0; i < 14; i++ {
            let start = Int(arc4random() % 14)
            str += letters[start]
        }
        return "com.vluxe.swifthttp.request.\(str)"
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
    
    func download(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        let serialReq = createRequest(url,method: .GET, parameters: parameters)
        if serialReq.error {
            failure(serialReq.error!)
            return
        }
        let config = NSURLSessionConfiguration.backgroundSessionConfiguration(createBackgroundIdent())
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.downloadTaskWithRequest(serialReq.request)
    }
    
    func upload(url: String, parameters: Dictionary<String,AnyObject>?, success:((AnyObject?) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        let serialReq = createRequest(url,method: .GET, parameters: parameters)
        if serialReq.error {
            failure(serialReq.error!)
            return
        }
        let config = NSURLSessionConfiguration.backgroundSessionConfiguration(createBackgroundIdent())
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        //session.uploadTaskWithRequest(serialReq.request, fromData: nil)
    }
   
}
