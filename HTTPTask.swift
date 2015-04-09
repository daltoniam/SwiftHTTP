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
    /// The body or response data of the HTTP Response.
    public var responseObject: AnyObject?
    /// The status code of the HTTP Response.
    public var statusCode: Int?
    ///Returns the response as a string
    public func text() -> String? {
        if let d = self.responseObject as? NSData {
            return  NSString(data: d, encoding: NSUTF8StringEncoding) as? String
        }
        return nil
    }
    /// The URL of the HTTP Response.
    public var URL: NSURL?
}

/// Holds the blocks of the background task.
class BackgroundBlocks {
    // these 2 only get used for background download/upload since they have to be delegate methods
    var success:((HTTPResponse) -> Void)?
    var failure:((NSError, HTTPResponse?) -> Void)?
    var progress:((Double) -> Void)?
    
    /** 
        Initializes a new Background Block
        
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
        :param: progress The block that is run on the progress of a HTTP Upload or Download.
    */
    init(_ success: ((HTTPResponse) -> Void)?, _ failure: ((NSError, HTTPResponse?) -> Void)?,_ progress: ((Double) -> Void)?) {
        self.failure = failure
        self.success = success
        self.progress = progress
    }
}

/// Subclass of NSOperation for handling and scheduling HTTPTask on a NSOperationQueue.
public class HTTPOperation : NSOperation {
    private var task: NSURLSessionDataTask!
    private var stopped = false
    private var running = false
    
    /// Controls if the task is finished or not.
    public var done = false
    
    //MARK: Subclassed NSOperation Methods
    
    /// Returns if the task is asynchronous or not. This should always be false.
    override public var asynchronous: Bool {
        return false
    }
    
    /// Returns if the task has been cancelled or not.
    override public var cancelled: Bool {
        return stopped
    }
    
    /// Returns if the task is current running.
    override public var executing: Bool {
        return running
    }
    
    /// Returns if the task is finished.
    override public var finished: Bool {
        return done
    }
    
    /// Returns if the task is ready to be run or not.
    override public var ready: Bool {
        return !running
    }
    
    /// Starts the task.
    override public func start() {
        super.start()
        stopped = false
        running = true
        done = false
        task.resume()
    }
    
    /// Cancels the running task.
    override public func cancel() {
        super.cancel()
        running = false
        stopped = true
        done = true
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
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    
        :returns: A freshly constructed HTTPOperation to add to your NSOperationQueue.
    */
    public func create(url: String, method: HTTPMethod, parameters: Dictionary<String,AnyObject>!, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) ->  HTTPOperation? {

        let serialReq = createRequest(url, method: method, parameters: parameters)
        if serialReq.error != nil {
            if failure != nil {
                failure(serialReq.error!, nil)
            }
            return nil
        }
        let opt = HTTPOperation()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTaskWithRequest(serialReq.request,
            completionHandler: {(data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                opt.finish()
                if error != nil {
                    if failure != nil {
                        failure(error, nil)
                    }
                    return
                }
                if data != nil {
                    var responseObject: AnyObject = data
                    if self.responseSerializer != nil {
                        let resObj = self.responseSerializer!.responseObjectFromResponse(response, data: data)
                        if resObj.error != nil {
                            if failure != nil {
                                failure(resObj.error!, nil)
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
                        extraResponse.URL = hresponse.URL
                    }
                    extraResponse.responseObject = responseObject
                    if extraResponse.statusCode > 299 {
                        if failure != nil {
                            failure(self.createError(extraResponse.statusCode!), extraResponse)
                        }
                    } else if success != nil {
                        success(extraResponse)
                    }
                } else if failure != nil {
                    failure(error, nil)
                }
            })
        opt.task = task
        return opt
    }
    
    /**
        Creates a HTTPOperation as a HTTP GET request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func GET(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) {
        var opt = self.create(url, method:.GET, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP POST request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func POST(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) {
        var opt = self.create(url, method:.POST, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    /**
    Creates a HTTPOperation as a HTTP PATCH request and starts it for you.
    
    :param: url The url you would like to make a request to.
    :param: parameters The parameters are HTTP parameters you would like to send.
    :param: success The block that is run on a sucessful HTTP Request.
    :param: failure The block that is run on a failed HTTP Request.
    */
    public func PATCH(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) {
        var opt = self.create(url, method:.PATCH, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    
    /**
        Creates a HTTPOperation as a HTTP PUT request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func PUT(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) {
        var opt = self.create(url, method:.PUT, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP DELETE request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func DELETE(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!)  {
        var opt = self.create(url, method:.DELETE, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    /**
        Creates a HTTPOperation as a HTTP HEAD request and starts it for you.
        
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: success The block that is run on a sucessful HTTP Request.
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func HEAD(url: String, parameters: Dictionary<String,AnyObject>?, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) {
        var opt = self.create(url, method:.HEAD, parameters: parameters,success: success,failure: failure)
        if opt != nil {
            opt!.start()
        }
    }
    
    /**
        Creates and starts a HTTPOperation to download a file in the background.
    
        :param: url The url you would like to make a request to.
        :param: parameters The parameters are HTTP parameters you would like to send.
        :param: progress The progress returned in the progress block is between 0 and 1.
        :param: success The block that is run on a sucessful HTTP Request. The HTTPResponse responseObject object will be a fileURL. You MUST copy the fileURL return in HTTPResponse.responseObject to a new location before using it (e.g. your documents directory).
        :param: failure The block that is run on a failed HTTP Request.
    */
    public func download(url: String, parameters: Dictionary<String,AnyObject>?,progress:((Double) -> Void)!, success:((HTTPResponse) -> Void)!, failure:((NSError, HTTPResponse?) -> Void)!) -> NSURLSessionDownloadTask? {
        let serialReq = createRequest(url,method: .GET, parameters: parameters)
        if serialReq.error != nil {
            failure(serialReq.error!, nil)
            return nil
        }
        let ident = createBackgroundIdent()
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(ident)
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTaskWithRequest(serialReq.request)
        self.backgroundTaskMap[ident] = BackgroundBlocks(success,failure,progress)
        //this does not have to be queueable as Apple's background dameon *should* handle that.
        task.resume()
        return task
    }
    
    //TODO: not implemented yet.
    /// not implemented yet.
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
        self.backgroundTaskMap.removeValueForKey(identifier)
    }
    
    //MARK: NSURLSession Delegate Methods
    
    /// Method for authentication challenge.
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {
        if let a = auth {
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
    
    /// Called when the background task failed.
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let err = error {
            let blocks = self.backgroundTaskMap[session.configuration.identifier]
            if blocks?.failure != nil { //Swift bug. Can't use && with block (radar: 17469794)
                blocks?.failure!(err, nil)
                cleanupBackground(session.configuration.identifier)
            }
        }
    }
    
    /// The background download finished and reports the url the data was saved to.
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
        let blocks = self.backgroundTaskMap[session.configuration.identifier]
        if blocks?.success != nil {
            var resp = HTTPResponse()
            if let hresponse = downloadTask.response as? NSHTTPURLResponse {
                resp.headers = hresponse.allHeaderFields as? Dictionary<String,String>
                resp.mimeType = hresponse.MIMEType
                resp.suggestedFilename = hresponse.suggestedFilename
                resp.statusCode = hresponse.statusCode
                resp.URL = hresponse.URL
            }
            resp.responseObject = location
            if resp.statusCode > 299 {
                if blocks?.failure != nil {
                    blocks?.failure!(self.createError(resp.statusCode!), resp)
                }
                return
            }
            blocks?.success!(resp)
            cleanupBackground(session.configuration.identifier)
        }
    }
    
    /// Will report progress of background download
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
    
    /// The background download finished, don't have to really do anything.
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
    }
    
    //TODO: not implemented yet.
    /// not implemented yet. The background upload finished and reports the response data (if any).
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {
        //add upload finished logic
    }
    
    //TODO: not implemented yet.
    /// not implemented yet.
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        //add progress block logic
    }
    
    //TODO: not implemented yet.
    /// not implemented yet.
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
}
