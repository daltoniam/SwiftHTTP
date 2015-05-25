//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPTask.swift
//
//  Created by Dalton Cherry on 6/3/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

/// HTTP Verbs.
///
/// - GET: For GET requests.
/// - POST: For POST requests.
/// - PUT: For PUT requests.
/// - HEAD: For HEAD requests.
/// - DELETE: For DELETE requests.
/// - PATCH: For PATCH requests.
public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

/// Object representation of a HTTP Response.
public class HTTPResponse {
    /// The header values in HTTP response.
    public var headers: Dictionary<String,String>?
    /// The mime type of the HTTP response.
    public var mimeType: String?
    /// The suggested filename for a downloaded file.
    public var suggestedFilename: String?
    /// The body or response data of the HTTP response.
    public var responseObject: AnyObject?
    /// The status code of the HTTP response.
    public var statusCode: Int?
    /// The URL of the HTTP response.
    public var URL: NSURL?
    /// The Error of the HTTP response (if there was one).
    public var error: NSError?
    ///Returns the response as a string
    public var text: String? {
        if let d = self.responseObject as? NSData {
            return  NSString(data: d, encoding: NSUTF8StringEncoding) as? String
        } else if let val: AnyObject = self.responseObject {
            return  "\(val)"
        }
        return nil
    }
    //get the description of the response
    public var description: String {
        var buffer = ""
        if let u = self.URL {
            buffer += "URL:\n\(u)\n\n"
        }
        if let code = self.statusCode {
            buffer += "Status Code:\n\(code)\n\n"
        }
        if let heads = self.headers {
            buffer += "Headers:\n"
            for (key, value) in heads {
                buffer += "\(key): \(value)\n"
            }
            buffer += "\n"
        }
        if let s = self.text {
            buffer += "Payload:\n\(s)\n"
        }
        return buffer
    }
}

/// Holds the blocks of the background task.
class BackgroundBlocks {
    // these 2 only get used for background download/upload since they have to be delegate methods
    var completionHandler:((HTTPResponse) -> Void)?
    var progress:((Double) -> Void)?
    
    /** 
        Initializes a new Background Block
        
        :param: completionHandler The closure that is run when a HTTP Request finished.
        :param: progress The closure that is run on the progress of a HTTP Upload or Download.
    */
    init(_ completionHandler: ((HTTPResponse) -> Void)?,_ progress: ((Double) -> Void)?) {
        self.completionHandler = completionHandler
        self.progress = progress
    }
}

/// Subclass of NSOperation for handling and scheduling HTTPTask on a NSOperationQueue.
public class HTTPOperation : NSOperation {
    private var task: NSURLSessionDataTask!
    private var running = false
    
    /// Controls if the task is finished or not.
    private var done = false
    
    //MARK: Subclassed NSOperation Methods
    
    /// Returns if the task is asynchronous or not. NSURLSessionTask requests are asynchronous.
    override public var asynchronous: Bool {
        return true
    }
    
    /// Returns if the task is current running.
    override public var executing: Bool {
        return running
    }
    
    /// Returns if the task is finished.
    override public var finished: Bool {
        return done
    }
    
    /// Starts the task.
    override public func start() {
        if cancelled {
            self.willChangeValueForKey("isFinished")
            done = true
            self.didChangeValueForKey("isFinished")
            return
        }

        self.willChangeValueForKey("isExecuting")
        self.willChangeValueForKey("isFinished")

        running = true
        done = false
        
        self.didChangeValueForKey("isExecuting")
        self.didChangeValueForKey("isFinished")

        task.resume()
    }
    
    /// Cancels the running task.
    override public func cancel() {
        super.cancel()
        task.cancel()
    }
    
    /// Sets the task to finished.
    public func finish() {
        self.willChangeValueForKey("isExecuting")
        self.willChangeValueForKey("isFinished")
        
        running = false
        done = true
        
        self.didChangeValueForKey("isExecuting")
        self.didChangeValueForKey("isFinished")
    }
}

/// Configures NSURLSession Request for HTTPOperation. Also provides convenience methods for easily running HTTP Request.
public class HTTPTask : NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate {
    var backgroundTaskMap = Dictionary<String,BackgroundBlocks>()
    //var sess: NSURLSession?
    
    public var baseURL: String?
    public var requestSerializer = HTTPRequestSerializer()
    public var responseSerializer: HTTPResponseSerializer?
    //This gets called on auth challenges. If nil, default handling is use.
    //Returning nil from this method will cause the request to be rejected and cancelled
    public var auth:((NSURLAuthenticationChallenge) -> NSURLCredential?)?
    
    //This is for doing SSL pinning
    public var security: HTTPSecurity?
    
    //MARK: Public Methods
    
    /// A newly minted HTTPTask for your enjoyment.
    public override init() {
        super.init()
    }
    
    /** 
        Creates a HTTPOperation that can be scheduled on a NSOperationQueue. Called by convenience HTTP verb methods below.
    
        :param: url The url you would like to make a request to.
        :param: method The HTTP method/verb for the request.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: completionHandler The closure that is run when a HTTP Request finished.
    
        :returns: A freshly constructed HTTPOperation to add to your NSOperationQueue.
    */
    public func create(url: String, method: HTTPMethod, parameters: Dictionary<String,AnyObject>!, completionHandler:((HTTPResponse) -> Void)!) ->  HTTPOperation? {
        
        var serialResponse = HTTPResponse()
        let serialReq = createRequest(url, method: method, parameters: parameters)
        if let err = serialReq.error {
            if let handler = completionHandler {
                serialResponse.error = err
                handler(serialResponse)
            }
            return nil
        }
        let opt = HTTPOperation()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTaskWithRequest(serialReq.request,
            completionHandler: {(data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if let handler = completionHandler {
                    if let hresponse = response as? NSHTTPURLResponse {
                        serialResponse.headers = hresponse.allHeaderFields as? Dictionary<String,String>
                        serialResponse.mimeType = hresponse.MIMEType
                        serialResponse.suggestedFilename = hresponse.suggestedFilename
                        serialResponse.statusCode = hresponse.statusCode
                        serialResponse.URL = hresponse.URL
                    }
                    serialResponse.error = error
                    if let d = data {
                        serialResponse.responseObject = d
                        if let resSerializer = self.responseSerializer {
                            let resObj = resSerializer.responseObjectFromResponse(response, data: d)
                            serialResponse.responseObject = resObj.object
                            serialResponse.error = resObj.error
                        }
                        if let code = serialResponse.statusCode where serialResponse.statusCode > 299 {
                            serialResponse.error = self.createError(code)
                        }
                    }
                    handler(serialResponse)
                }
                opt.finish()
            })
        opt.task = task
        return opt
    }
    
    /**
    Creates a HTTPOperation as a HTTP GET request and starts it for you.
    
    :param: url The url you would like to make a request to.
    :param: parameters The parameters are HTTP parameters you would like to send.
    :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func GET(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!) {
        if let opt = self.create(url, method:.GET, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP POST request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func POST(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!) {
        if let opt = self.create(url, method:.POST, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    /**
    Creates a HTTPOperation as a HTTP PATCH request and starts it for you.
    
    :param: url The url you would like to make a request to.
    :param: parameters The parameters are HTTP parameters you would like to send.
    :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func PATCH(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!) {
        if let opt = self.create(url, method:.PATCH, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    
    /**
        Creates a HTTPOperation as a HTTP PUT request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func PUT(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!) {
        if let opt = self.create(url, method:.PUT, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP DELETE request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func DELETE(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!)  {
        if let opt = self.create(url, method:.DELETE, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP HEAD request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func HEAD(url: String, parameters: Dictionary<String,AnyObject>?, completionHandler:((HTTPResponse) -> Void)!) {
        if let opt = self.create(url, method:.HEAD, parameters: parameters,completionHandler: completionHandler) {
            opt.start()
        }
    }
    
    /**
        Creates and starts a HTTPOperation to download a file in the background.
    
        :param: url The url you would like to make a request to.
        :param: method The HTTP method you want to use. Default is GET.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: progress The progress returned in the progress closure is between 0 and 1.
        :param: completionHandler The closure that is run when the HTTP Request finishes. The HTTPResponse responseObject object will be a fileURL. You MUST copy the fileURL return in HTTPResponse.responseObject to a new location before using it (e.g. your documents directory).
    */
    public func download(url: String, method: HTTPMethod = .GET, parameters: Dictionary<String,AnyObject>?,progress:((Double) -> Void)!, completionHandler:((HTTPResponse) -> Void)!) -> NSURLSessionDownloadTask? {
        let serialReq = createRequest(url,method: method, parameters: parameters)
        if let err = serialReq.error {
            if let handler = completionHandler {
                var res = HTTPResponse()
                res.error = err
                handler(res)
            }
            return nil
        }
        let ident = createBackgroundIdent()
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(ident)
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTaskWithRequest(serialReq.request)
        backgroundTaskMap[ident] = BackgroundBlocks(completionHandler,progress)
        //this does not have to be queueable as Apple's background dameon *should* handle that.
        task.resume()
        return task
    }
    
    /**
    Creates and starts a HTTPOperation to upload a file in the background.
    
    :param: url The url you would like to make a request to.
    :param: method The HTTP method you want to use. Default is POST.
    :param: parameters The parameters are HTTP parameters you would like to send.
    :param: progress The progress returned in the progress closure is between 0 and 1.
    :param: completionHandler The closure that is run when a HTTP Request finished.
    */
    public func upload(url: String, method: HTTPMethod = .POST, parameters: Dictionary<String,AnyObject>?,progress:((Double) -> Void)!, completionHandler:((HTTPResponse) -> Void)!) -> NSURLSessionTask? {
        let serialReq = createRequest(url,method: method, parameters: parameters)
        if let err = serialReq.error {
            if let handler = completionHandler {
                var res = HTTPResponse()
                res.error = err
                handler(res)
            }
            return nil
        }
        let ident = createBackgroundIdent()
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(ident)
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.uploadTaskWithStreamedRequest(serialReq.request)
        backgroundTaskMap[ident] = BackgroundBlocks(completionHandler,progress)
        task.resume()
        return task
    }
    
    //MARK: Private Helper Methods
    
    /**
        Creates and starts a HTTPOperation to download a file in the background.
    
        :param: url The url you would like to make a request to.
        :param: method The HTTP method/verb for the request.
        :param: parameters The parameters are HTTP parameters you would like to send.
    
        :returns: A NSURLRequest from configured requestSerializer.
    */
   private func createRequest(url: String, method: HTTPMethod, parameters: Dictionary<String,AnyObject>!) -> (request: NSURLRequest, error: NSError?) {
        var urlVal = url
        //probably should change the 'http' to something more generic
        if !url.hasPrefix("http") && self.baseURL != nil {
            var split = url.hasPrefix("/") ? "" : "/"
            urlVal = "\(self.baseURL!)\(split)\(url)"
        }
    if let u = NSURL(string: urlVal) {
        return self.requestSerializer.createRequest(u, method: method, parameters: parameters)
    }
    return (NSURLRequest(),createError(-1001))
    }
    
    /**
        Creates a random string to use for the identifier of the background download/upload requests.
    
        :returns: Identifier String.
    */
    private func createBackgroundIdent() -> String {
        let letters = "abcdefghijklmnopqurstuvwxyz"
        var str = ""
        for var i = 0; i < 14; i++ {
            let start = Int(arc4random() % 14)
            str.append(letters[advance(letters.startIndex,start)])
        }
        return "com.vluxe.swifthttp.request.\(str)"
    }
    
    /**
        Creates a random string to use for the identifier of the background download/upload requests.
        
        :param: code Code for error.
        
        :returns: An NSError.
    */
    private func createError(code: Int) -> NSError {
        var text = "An error occured"
        if code == 404 {
            text = "Page not found"
        } else if code == 401 {
            text = "Access denied"
        } else if code == -1001 {
            text = "Invalid URL"
        }
        return NSError(domain: "HTTPTask", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
    
    
    /**
        Creates a random string to use for the identifier of the background download/upload requests.
        
        :param: identifier The identifier string.
        
        :returns: An NSError.
    */
    private func cleanupBackground(identifier: String) {
        backgroundTaskMap.removeValueForKey(identifier)
    }
    
    //MARK: NSURLSession Delegate Methods
    
    /// Method for authentication challenge.
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {
        if let sec = security where challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let space = challenge.protectionSpace
            if let trust = space.serverTrust {
                if sec.isValid(trust, domain: space.host) {
                    completionHandler(.UseCredential, NSURLCredential(trust: trust))
                    return
                }
            }
            completionHandler(.CancelAuthenticationChallenge, nil)
            return
            
        } else if let a = auth {
            let cred = a(challenge)
            if let c = cred {
                completionHandler(.UseCredential, c)
                return
            }
            completionHandler(.RejectProtectionSpace, nil)
            return
        }
        completionHandler(.PerformDefaultHandling, nil)
    }
    
    //MARK: Methods for background download/upload
    
    ///update the download/upload progress closure
    func handleProgress(session: NSURLSession, totalBytesExpected: Int64, currentBytes: Int64) {
        if session.configuration.valueForKey("identifier") != nil { //temp workaround for radar: 21097168
            let increment = 100.0/Double(totalBytesExpected)
            var current = (increment*Double(currentBytes))*0.01
            if current > 1 {
                current = 1;
            }
            if let blocks = backgroundTaskMap[session.configuration.identifier] {
                if blocks.progress != nil {
                    blocks.progress!(current)
                }
            }
        }
    }
    
    //call the completionHandler closure for upload/download requests
    func handleFinish(session: NSURLSession, task: NSURLSessionTask, response: AnyObject) {
        if session.configuration.valueForKey("identifier") != nil { //temp workaround for radar: 21097168
            if let blocks = backgroundTaskMap[session.configuration.identifier] {
                if let handler = blocks.completionHandler {
                    var resp = HTTPResponse()
                    if let hresponse = task.response as? NSHTTPURLResponse {
                        resp.headers = hresponse.allHeaderFields as? Dictionary<String,String>
                        resp.mimeType = hresponse.MIMEType
                        resp.suggestedFilename = hresponse.suggestedFilename
                        resp.statusCode = hresponse.statusCode
                        resp.URL = hresponse.URL
                    }
                    resp.responseObject = response
                    if let code = resp.statusCode where resp.statusCode > 299 {
                        resp.error = self.createError(code)
                    }
                    handler(resp)
                }
            }
            cleanupBackground(session.configuration.identifier)
        }
    }
    
    /// Called when the background task failed.
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let err = error {
            if session.configuration.valueForKey("identifier") != nil { //temp workaround for radar: 21097168
                if let blocks = backgroundTaskMap[session.configuration.identifier] {
                    if let handler = blocks.completionHandler {
                        var res = HTTPResponse()
                        res.error = err
                        handler(res)
                    }
                }
                cleanupBackground(session.configuration.identifier)
            }
        }
    }
    
    /// The background download finished and reports the url the data was saved to.
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL!) {
        handleFinish(session, task: downloadTask, response: location)
    }
    
    /// Will report progress of background download
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        handleProgress(session, totalBytesExpected: totalBytesExpectedToWrite, currentBytes:totalBytesWritten)
    }
    
    /// The background download finished, don't have to really do anything.
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
    }
    
    /// The background upload finished and reports the response.
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData!) {
        handleFinish(session, task: dataTask, response: data)
    }
    
    ///Will report progress of background upload
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        handleProgress(session, totalBytesExpected: totalBytesExpectedToSend, currentBytes:totalBytesSent)
    }
    
    //implement if we want to support partial file upload/download
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
    }
}
