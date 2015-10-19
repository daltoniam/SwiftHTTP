//
//  Operation.swift
//  SwiftHTTP
//
//  Created by Dalton Cherry on 8/2/15.
//  Copyright © 2015 vluxe. All rights reserved.
//

import Foundation

enum HTTPOptError: ErrorType {
    case InvalidRequest
}

/**
This protocol exist to allow easy and customizable swapping of a serializing format within an class methods of HTTP.
*/
public protocol HTTPSerializeProtocol {
    
    /**
    implement this protocol to support serializing parameters to the proper HTTP body or URL
    -parameter request: The NSMutableURLRequest object you will modify to add the parameters to
    -parameter parameters: The container (array or dictionary) to convert and append to the URL or Body
    */
    func serialize(request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws
}

/**
Standard HTTP encoding
*/
public struct HTTPParameterSerializer: HTTPSerializeProtocol {
    public init() { }
    public func serialize(request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws {
        try request.appendParameters(parameters)
    }
}

/**
Send the data as a JSON body
*/
public struct JSONParameterSerializer: HTTPSerializeProtocol {
    public init() { }
    public func serialize(request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws {
         try request.appendParametersAsJSON(parameters)
    }
}

/**
All the things of an HTTP response
*/
public class Response {
    /// The header values in HTTP response.
    public var headers: Dictionary<String,String>?
    /// The mime type of the HTTP response.
    public var mimeType: String?
    /// The suggested filename for a downloaded file.
    public var suggestedFilename: String?
    /// The body data of the HTTP response.
    public var data: NSData {
        return collectData
    }
    /// The status code of the HTTP response.
    public var statusCode: Int?
    /// The URL of the HTTP response.
    public var URL: NSURL?
    /// The Error of the HTTP response (if there was one).
    public var error: NSError?
    ///Returns the response as a string
    public var text: String? {
        return  NSString(data: data, encoding: NSUTF8StringEncoding) as? String
    }
    ///get the description of the response
    public var description: String {
        var buffer = ""
        if let u = URL {
            buffer += "URL:\n\(u)\n\n"
        }
        if let code = self.statusCode {
            buffer += "Status Code:\n\(code)\n\n"
        }
        if let heads = headers {
            buffer += "Headers:\n"
            for (key, value) in heads {
                buffer += "\(key): \(value)\n"
            }
            buffer += "\n"
        }
        if let t = text {
            buffer += "Payload:\n\(t)\n"
        }
        return buffer
    }
    ///private things
    
    ///holds the collected data
    var collectData = NSMutableData()
    ///finish closure
    var completionHandler:((Response) -> Void)?
    
    //progress closure. Progress is between 0 and 1.
    var progressHandler:((Float) -> Void)?
    
    ///This gets called on auth challenges. If nil, default handling is use.
    ///Returning nil from this method will cause the request to be rejected and cancelled
    var auth:((NSURLAuthenticationChallenge) -> NSURLCredential?)?
    
    ///This is for doing SSL pinning
    var security: HTTPSecurity?
}

/**
The class that does the magic. Is a subclass of NSOperation so you can use it with operation queues or just a good ole HTTP request.
*/
public class HTTP: NSOperation {
    /**
    Get notified with a request finishes.
    */
    public var onFinish:((Response) -> Void)? {
        didSet {
            if let handler = onFinish {
                DelegateManager.sharedInstance.addTask(task, completionHandler: { (response: Response) in
                    self.finish()
                    handler(response)
                })
            }
        }
    }
    ///This is for handling authenication
    public var auth:((NSURLAuthenticationChallenge) -> NSURLCredential?)? {
        set {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return }
            resp.auth = newValue
        }
        get {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return nil }
            return resp.auth
        }
    }
    
    ///This is for doing SSL pinning
    public var security: HTTPSecurity? {
        set {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return }
            resp.security = newValue
        }
        get {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return nil }
            return resp.security
        }
    }
    
    ///This is for monitoring progress
    public var progress: ((Float) -> Void)? {
        set {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return }
            resp.progressHandler = newValue
        }
        get {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return nil }
            return resp.progressHandler
        }
    }
    
    ///the actual task
    var task: NSURLSessionDataTask!
    /// Reports if the task is currently running
    private var running = false
    /// Reports if the task is finished or not.
    private var done = false
    
    /**
    creates a new HTTP request.
    */
    public init(_ req: NSURLRequest, session: NSURLSession = SharedSession.defaultSession) {
        super.init()
        task = session.dataTaskWithRequest(req)
        DelegateManager.sharedInstance.addResponseForTask(task)
    }
    
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
    
    /**
    start/sends the HTTP task with a completionHandler. Use this when *NOT* using an NSOperationQueue.
    */
    public func start(completionHandler:((Response) -> Void)) {
        onFinish = completionHandler
        start()
    }
    
    /**
    Start the HTTP task. Make sure to set the onFinish closure before calling this to get a response.
    */
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
    
    /**
    Cancel the running task
    */
    override public func cancel() {
        task.cancel()
        finish()
    }
    /**
     Sets the task to finished. 
    If you aren't using the DelegateManager, you will have to call this in your delegate's URLSession:dataTask:didCompleteWithError: method
    */
    public func finish() {
        self.willChangeValueForKey("isExecuting")
        self.willChangeValueForKey("isFinished")
        
        running = false
        done = true
        
        self.didChangeValueForKey("isExecuting")
        self.didChangeValueForKey("isFinished")
    }
    
    /**
    Class method to create a GET request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func GET(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil,
        requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .GET, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a HEAD request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func HEAD(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .HEAD, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a DELETE request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func DELETE(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .DELETE, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a POST request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func POST(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .POST, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a PUT request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func PUT(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil,
        requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .PUT, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a PUT request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func PATCH(url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .PATCH, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a HTTP request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    public class func New(url: String, method: HTTPVerb, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        guard let req = NSMutableURLRequest(urlString: url) else { throw HTTPOptError.InvalidRequest }
        if let handler = DelegateManager.sharedInstance.requestHandler {
            handler(req)
        }
        req.verb = method
        if let params = parameters {
            try requestSerializer.serialize(req, parameters: params)
        }
        if let heads = headers {
            for (key,value) in heads {
                req.addValue(value, forHTTPHeaderField: key)
            }
        }
        return HTTP(req)
    }
    
    /**
    Set the global auth handler
    */
    public class func globalAuth(handler: ((NSURLAuthenticationChallenge) -> NSURLCredential?)?) {
        DelegateManager.sharedInstance.auth = handler
    }
    
    /**
    Set the global security handler
    */
    public class func globalSecurity(security: HTTPSecurity?) {
        DelegateManager.sharedInstance.security = security
    }
    
    /**
    Set the global request handler
    */
    public class func globalRequest(handler: ((NSMutableURLRequest) -> Void)?) {
        DelegateManager.sharedInstance.requestHandler = handler
    }
}

/**
Absorb all the delegates methods of NSURLSession and forwards them to pretty closures.
This is basically the sin eater for NSURLSession.
*/
class DelegateManager: NSObject, NSURLSessionDataDelegate {
    //the singleton to handle delegate needs of NSURLSession
    static let sharedInstance = DelegateManager()
    
    /// this is for global authenication handling
    var auth:((NSURLAuthenticationChallenge) -> NSURLCredential?)?
    
    ///This is for global SSL pinning
    var security: HTTPSecurity?
    
    /// this is for global request handling
    var requestHandler:((NSMutableURLRequest) -> Void)?
    
    var taskMap = Dictionary<Int,Response>()
    //"install" a task by adding the task to the map and setting the completion handler
    func addTask(task: NSURLSessionTask, completionHandler:((Response) -> Void)) {
        addResponseForTask(task)
        if let resp = responseForTask(task) {
            resp.completionHandler = completionHandler
        }
    }
    
    //"remove" a task by removing the task from the map
    func removeTask(task: NSURLSessionTask) {
        taskMap.removeValueForKey(task.taskIdentifier)
    }
    
    //add the response task
    func addResponseForTask(task: NSURLSessionTask) {
        if taskMap[task.taskIdentifier] == nil {
            taskMap[task.taskIdentifier] = Response()
        }
    }
    //get the response object for the task
    func responseForTask(task: NSURLSessionTask) -> Response? {
        return taskMap[task.taskIdentifier]
    }
    
    //handle getting data
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        addResponseForTask(dataTask)
        guard let resp = responseForTask(dataTask) else { return }
        resp.collectData.appendData(data)
        if resp.progressHandler != nil { //don't want the extra cycles for no reason
            guard let taskResp = dataTask.response else { return }
            progressHandler(resp, expectedLength: taskResp.expectedContentLength, currentLength: Int64(resp.collectData.length))
        }
    }
    
    //handle task finishing
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        guard let resp = responseForTask(task) else { return }
        resp.error = error
        if let hresponse = task.response as? NSHTTPURLResponse {
            resp.headers = hresponse.allHeaderFields as? Dictionary<String,String>
            resp.mimeType = hresponse.MIMEType
            resp.suggestedFilename = hresponse.suggestedFilename
            resp.statusCode = hresponse.statusCode
            resp.URL = hresponse.URL
        }
        if let code = resp.statusCode where resp.statusCode > 299 {
            resp.error = createError(code)
        }
        if let handler = resp.completionHandler {
            handler(resp)
        }
        removeTask(task)
    }
    
    //handle authenication
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        var sec = security
        var au = auth
        if let resp = responseForTask(task) {
            if let s = resp.security {
                sec = s
            }
            if let a = resp.auth {
                au = a
            }
        }
        if let sec = sec where challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let space = challenge.protectionSpace
            if let trust = space.serverTrust {
                if sec.isValid(trust, domain: space.host) {
                    completionHandler(.UseCredential, NSURLCredential(trust: trust))
                    return
                }
            }
            completionHandler(.CancelAuthenticationChallenge, nil)
            return
            
        } else if let a = au {
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
    //upload progress
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let resp = responseForTask(task) else { return }
        progressHandler(resp, expectedLength: totalBytesExpectedToSend, currentLength: totalBytesSent)
    }
    //download progress
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let resp = responseForTask(downloadTask) else { return }
        progressHandler(resp, expectedLength: totalBytesExpectedToWrite, currentLength: bytesWritten)
    }
    
    //handle progress
    func progressHandler(response: Response, expectedLength: Int64, currentLength: Int64) {
        guard let handler = response.progressHandler else { return }
        let slice = 1/expectedLength
        handler(Float(slice*currentLength))
    }
    
    /**
    Create an error for response you probably don't want (400-500 HTTP responses for example).
    
    -parameter code: Code for error.
    
    -returns An NSError.
    */
    private func createError(code: Int) -> NSError {
        let text = HTTPStatusCode(statusCode: code).statusDescription
        return NSError(domain: "HTTP", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

/**
Handles providing singletons of NSURLSession.
*/
class SharedSession {
    static let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
        delegate: DelegateManager.sharedInstance, delegateQueue: nil)
    static let ephemeralSession = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration(),
        delegate: DelegateManager.sharedInstance, delegateQueue: nil)
}