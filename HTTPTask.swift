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
        return (((self as NSString).substringFromIndex(start)) as NSString).substringToIndex(to - start + 1)
    }
}

public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
}

//holds a collection of HTTP Response values
public class HTTPResponse {
    public var headers: Dictionary<String,String>?
    public var mimeType: String?
    public var suggestedFilename: String?
    public var responseObject: AnyObject?
    public var statusCode: Int?
}

//holds blocks of background task
public class BackgroundBlocks {
    //these 2 only get used for background download/upload since they have to be delegate methods
    var success:((HTTPResponse) -> Void)?
    var failure:((NSError) -> Void)?
    var progress:((Double) -> Void)?
    
    init(_ success: ((HTTPResponse) -> Void)?, _ failure: ((NSError) -> Void)?,_ progress: ((Double) -> Void)?) {
        self.failure = failure
        self.success = success
        self.progress = progress
    }
}

public class HTTPOperation : NSOperation {
    var task: NSURLSessionDataTask!
    var stopped = false
    var running = false
    public var done = false
    override public var asynchronous: Bool {
        return false
    }
    override public var cancelled: Bool {
        return self.stopped
    }
    override public var executing: Bool {
        return self.running
    }
    override public var finished: Bool {
        return self.done
    }
    override public var ready: Bool {
        return !self.running
    }
    //start the task
    override public func start() {
        super.start()
        self.stopped = false
        self.running = true
        self.done = false
        self.task.resume()
    }
    override public func cancel() {
        super.cancel()
        self.running = false
        self.stopped = true
        self.done = true
        self.task.cancel()
    }
    public func finish() {
        self.running = false
        self.done = true
    }
    
}

public class HTTPTask : NSObject, NSURLSessionDelegate {
    
    public var baseURL: String?
    public var requestSerializer = HTTPRequestSerializer()
    public var responseSerializer: HTTPResponseSerializer?
    var backgroundTaskMap = Dictionary<String,BackgroundBlocks>()
    public override init() {
        super.init()
    }
    
    ///main method that does the HTTP request. Called by GET,POST,PUT,DELETE,HEAD methods.
    public func create(url: String,method: HTTPMethod,parameters: Dictionary<String,AnyObject>!, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) ->  HTTPOperation? {
        
        let serialReq = createRequest(url,method: method, parameters: parameters)
        if serialReq.error != nil {
            if failure != nil {
                failure(serialReq.error!)
            }
            return nil
        }
        let opt = HTTPOperation()
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(serialReq.request,
            completionHandler: {(data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                opt.finish()
                if error != nil {
                    if failure != nil {
                        failure(error)
                    }
                    return
                }
                if data != nil {
                    var responseObject: AnyObject = data
                    if self.responseSerializer != nil {
                        let resObj = self.responseSerializer!.responseObjectFromResponse(response, data: data)
                        if resObj.error != nil {
                            if failure != nil {
                                failure(resObj.error!)
                            }
                            return
                        }
                        if resObj.object != nil {
                            responseObject = resObj.object!
                        }
                    }
                    var extraResponse = HTTPResponse()
                    if let hresponse = response as? NSHTTPURLResponse {
                        extraResponse.headers = hresponse.allHeaderFields as? Dictionary<String,String>
                        extraResponse.mimeType = hresponse.MIMEType
                        extraResponse.suggestedFilename = hresponse.suggestedFilename
                        extraResponse.statusCode = hresponse.statusCode
                    }
                    extraResponse.responseObject = responseObject
                    if extraResponse.statusCode > 299 {
                        if failure != nil {
                            failure(self.createError(extraResponse.statusCode!))
                        }
                    } else if success != nil {
                        success(extraResponse)
                    }
                } else if failure != nil {
                    failure(error)
                }
            })
        opt.task = task
        return opt
    }
    ///runs a GET request
    public func GET(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) {
        var opt = self.create(url, method:.GET, parameters: parameters,success,failure)
        if opt != nil {
            opt!.start()
        }
    }
    ///runs a POST request
    public func POST(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) {
        var opt = self.create(url, method:.POST, parameters: parameters,success,failure)
        if opt != nil {
            opt!.start()
        }
    }
    ///runs a PUT request
    public func PUT(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) {
        var opt = self.create(url, method:.PUT, parameters: parameters,success,failure)
        if opt != nil {
            opt!.start()
        }
    }
    ///runs a DELETE request
    public func DELETE(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!)  {
        var opt = self.create(url, method:.DELETE, parameters: parameters,success,failure)
        if opt != nil {
            opt!.start()
        }
    }
    ///runs a HEAD request
    public func HEAD(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) {
        var opt = self.create(url, method:.HEAD, parameters: parameters,success,failure)
        if opt != nil {
            opt!.start()
        }
    }
    //Download a file in the background. The HTTPResponse responseObject object will be a fileURL.
    //You MUST copy the fileURL return in HTTPResponse.responseObject to a new location before using it (e.g. your documents directory).
    //The progress returned in the progress block is between 0 and 1.
    public func download(url: String, parameters: Dictionary<String,AnyObject>?,progress:((Double) -> Void)!, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) {
        let serialReq = createRequest(url,method: .GET, parameters: parameters)
        if serialReq.error != nil {
            failure(serialReq.error!)
            return
        }
        let ident = createBackgroundIdent()
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(ident)
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTaskWithRequest(serialReq.request)
        self.backgroundTaskMap[ident] = BackgroundBlocks(success,failure,progress)
        //this does not have to be queueable as Apple's background dameon *should* handle that.
        task.resume()
    }
    
    public func uploadFile(url: String, parameters: Dictionary<String,AnyObject>?, progress:((Double) -> Void)!, success:((HTTPResponse) -> Void)!, failure:((NSError) -> Void)!) -> Void {
        let serialReq = createRequest(url,method: .GET, parameters: parameters)
        if serialReq.error != nil {
            failure(serialReq.error!)
            return
        }
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(createBackgroundIdent())
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        //session.uploadTaskWithRequest(serialReq.request, fromData: nil)
    }
    
    //private methods below
    
    ///creates the request object.
    func createRequest(url: String,method: HTTPMethod,parameters: Dictionary<String,AnyObject>!) -> (request: NSURLRequest, error: NSError?) {
        var urlVal = url
        //probably should change the 'http' to something more generic
        if !url.hasPrefix("http") && self.baseURL != nil {
            var split = url.hasPrefix("/") ? "" : "/"
            urlVal = "\(self.baseURL!)\(split)\(url)"
        }
        //println("requestSerializer: \(self.requestSerializer)")
        return self.requestSerializer.createRequest(NSURL.URLWithString(urlVal),
            method: method, parameters: parameters)
        
    }
    ///creates a random string to use for the identifer of the background download/upload requests
    private func createBackgroundIdent() -> String {
        let letters = "abcdefghijklmnopqurstuvwxyz"
        var str = ""
        for var i = 0; i < 14; i++ {
            let start = Int(arc4random() % 14)
            str += letters[start]
        }
        return "com.vluxe.swifthttp.request.\(str)"
    }
    
    ///creates a random string to use for the identifer of the background download/upload requests
    private func createError(code: Int) -> NSError {
        var text = "An error occured"
        if code == 404 {
            text = "page not found"
        } else if code == 401 {
            text = "accessed denied"
        }
        return NSError(domain: "HTTPTask", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
    
    //the background download finished, don't have to really do anything
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
    }
    
    //the background task failed.
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
        if error != nil {
            let blocks = self.backgroundTaskMap[session.configuration.identifier]
            if blocks?.failure != nil { //Swift bug. Can't use && with block (radar: 17469794)
                blocks?.failure!(error)
                cleanupBackground(session.configuration.identifier)
            }
        }
    }
    
    //the background download finished and reports the url the data was saved to
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
        let blocks = self.backgroundTaskMap[session.configuration.identifier]
        if blocks?.success != nil {
            var resp = HTTPResponse()
            if let hresponse = downloadTask.response as? NSHTTPURLResponse {
                resp.headers = hresponse.allHeaderFields as? Dictionary<String,String>
                resp.mimeType = hresponse.MIMEType
                resp.suggestedFilename = hresponse.suggestedFilename
                resp.statusCode = hresponse.statusCode
            }
            resp.responseObject = location
            if resp.statusCode > 299 {
                if blocks?.failure != nil {
                    blocks?.failure!(self.createError(resp.statusCode!))
                }
                return
            }
            blocks?.success!(resp)
            cleanupBackground(session.configuration.identifier)
        }
    }
    //the background upload finished and reports the response data (if any)
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
        //add upload finished logic
    }
    //will report progress of background download
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let increment = 100.0/Double(totalBytesExpectedToWrite)
        var current = (increment*Double(totalBytesWritten))*0.01
        if current > 1 {
            current = 1;
        }
        let blocks = self.backgroundTaskMap[session.configuration.identifier]
        if blocks?.progress != nil {
            blocks?.progress!(current)
        }
    }
    //will report progress of background upload
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        //add progress block logic
    }
    //just have to implement, does nothing
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
    func cleanupBackground(identifier: String) {
        self.backgroundTaskMap.removeValueForKey(identifier)
    }
   
}
