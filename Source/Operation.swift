//
//  Operation.swift
//  SwiftHTTP
//
//  Created by Dalton Cherry on 8/2/15.
//  Copyright © 2015 vluxe. All rights reserved.
//

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


enum HTTPOptError: Error {
    case invalidRequest
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
    func serialize(_ request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws
}

/**
Standard HTTP encoding
*/
public struct HTTPParameterSerializer: HTTPSerializeProtocol {
    public init() { }
    public func serialize(_ request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws {
        try request.appendParameters(parameters)
    }
}

/**
Send the data as a JSON body
*/
public struct JSONParameterSerializer: HTTPSerializeProtocol {
    public init() { }
    public func serialize(_ request: NSMutableURLRequest, parameters: HTTPParameterProtocol) throws {
         try request.appendParametersAsJSON(parameters)
    }
}

/**
All the things of an HTTP response
*/
open class Response {
    /// The header values in HTTP response.
    open var headers: Dictionary<String,String>?
    /// The mime type of the HTTP response.
    open var mimeType: String?
    /// The suggested filename for a downloaded file.
    open var suggestedFilename: String?
    /// The body data of the HTTP response.
    open var data: Data {
        return collectData as Data
    }
    /// The status code of the HTTP response.
    open var statusCode: Int?
    /// The URL of the HTTP response.
    open var URL: Foundation.URL?
    /// The Error of the HTTP response (if there was one).
    open var error: NSError?
    ///Returns the response as a string
    open var text: String? {
        return  String(data: data, encoding: .utf8)
    }
    ///get the description of the response
    open var description: String {
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
    
    //download closure. the URL is the file URL where the temp file has been download. 
    //This closure will be called so you can move the file where you desire.
    var downloadHandler:((URL) -> Void)?
    
    ///This gets called on auth challenges. If nil, default handling is use.
    ///Returning nil from this method will cause the request to be rejected and cancelled
    var auth:((URLAuthenticationChallenge) -> URLCredential?)?
    
    ///This is for doing SSL pinning
    var security: HTTPSecurity?
}

/**
The class that does the magic. Is a subclass of NSOperation so you can use it with operation queues or just a good ole HTTP request.
*/
open class HTTP: Operation {
    /**
    Get notified with a request finishes.
    */
    open var onFinish:((Response) -> Void)? {
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
    open var auth:((URLAuthenticationChallenge) -> URLCredential?)? {
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
    open var security: HTTPSecurity? {
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
    open var progress: ((Float) -> Void)? {
        set {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return }
            resp.progressHandler = newValue
        }
        get {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return nil }
            return resp.progressHandler
        }
    }
    
    ///This is for handling downloads
    open var downloadHandler: ((URL) -> Void)? {
        set {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return }
            resp.downloadHandler = newValue
        }
        get {
            guard let resp = DelegateManager.sharedInstance.responseForTask(task) else { return nil }
            return resp.downloadHandler
        }
    }
    
    ///the actual task
    var task: URLSessionTask!
	
	fileprivate enum State: Int, Comparable {
		/// The initial state of an `Operation`.
		case initialized
		
		/**
		The `Operation`'s conditions have all been satisfied, and it is ready
		to execute.
		*/
		case ready
		
		/// The `Operation` is executing.
		case executing
		
		/// The `Operation` has finished executing.
		case finished
		
		/// what state transitions are allowed
		func canTransitionToState(_ target: State) -> Bool {
			switch (self, target) {
			case (.initialized, .ready):
				return true
			case (.ready, .executing):
				return true
			case (.ready, .finished):
				return true
			case (.executing, .finished):
				return true
			default:
				return false
			}
		}
	}
	
	/// Private storage for the `state` property that will be KVO observed. don't set directly!
	fileprivate var _state = State.initialized
	
	/// A lock to guard reads and writes to the `_state` property
	fileprivate let stateLock = NSLock()
	
	// use the KVO mechanism to indicate that changes to "state" affect ready, executing, finished properties
	class func keyPathsForValuesAffectingIsReady() -> Set<NSObject> {
		return ["state" as NSObject]
	}
	
	class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject> {
		return ["state" as NSObject]
	}
	
	class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
		return ["state" as NSObject]
	}
	
	// threadsafe
	fileprivate var state: State {
		get {
			return stateLock.withCriticalScope {
				_state
			}
		}
		set(newState) {
			willChangeValue(forKey: "state")
			stateLock.withCriticalScope { Void -> Void in
				guard _state != .finished else {
					print("Invalid! - Attempted to back out of Finished State")
					return
				}
				assert(_state.canTransitionToState(newState), "Performing invalid state transition.")
				_state = newState
			}
			didChangeValue(forKey: "state")
		}
	}
	
    /**
    creates a new HTTP request.
    */
    public init(_ req: URLRequest, session: URLSession = SharedSession.defaultSession, isDownload: Bool = false) {
        super.init()
        if isDownload {
            task = session.downloadTask(with: req)
        } else {
            task = session.dataTask(with: req)
        }
        DelegateManager.sharedInstance.addResponseForTask(task)
		state = .ready
    }
    
    //MARK: Subclassed NSOperation Methods
    
    /// Returns if the task is asynchronous or not. NSURLSessionTask requests are asynchronous.
    override open var isAsynchronous: Bool {
        return true
    }
	
	// If the operation has been cancelled, "isReady" should return true
	override open var isReady: Bool {
		switch state {
			
		case .initialized:
			return isCancelled
			
		case .ready:
			return super.isReady || isCancelled
			
		default:
			return false
		}
	}
	
    /// Returns if the task is current running.
	override open var isExecuting: Bool {
		return state == .executing
	}
	
	override open var isFinished: Bool {
		return state == .finished
	}
    
    /**
    start/sends the HTTP task with a completionHandler. Use this when *NOT* using an NSOperationQueue.
    */
    open func start(_ completionHandler:@escaping ((Response) -> Void)) {
        onFinish = completionHandler
        start()
    }
    
    /**
    Start the HTTP task. Make sure to set the onFinish closure before calling this to get a response.
    */
    override open func start() {
		if isCancelled {
			state = .finished
			return
		}
		
		state = .executing
		task.resume()
    }
	
    /**
    Cancel the running task
    */
    override open func cancel() {
        task.cancel()
        finish()
    }
    /**
     Sets the task to finished. 
    If you aren't using the DelegateManager, you will have to call this in your delegate's URLSession:dataTask:didCompleteWithError: method
    */
    open func finish() {
		state = .finished
    }
	
	/**
	Check not executing or finished when adding dependencies
	*/
	override open func addDependency(_ operation: Operation) {
		assert(state < .executing, "Dependencies cannot be modified after execution has begun.")
		super.addDependency(operation)
	}
	
	/**
	Convenience bool to flag as operation userInitiated if necessary
	*/
	var userInitiated: Bool {
		get {
			return qualityOfService == .userInitiated
		}
		set {
			assert(state < State.executing, "Cannot modify userInitiated after execution has begun.")
			qualityOfService = newValue ? .userInitiated : .default
		}
	}

    /**
    Class method to create a GET request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func GET(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil,
        requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .GET, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a HEAD request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func HEAD(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .HEAD, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a DELETE request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func DELETE(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .DELETE, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a POST request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func POST(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .POST, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a PUT request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func PUT(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil,
        requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .PUT, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
    Class method to create a PUT request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func PATCH(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer()) throws -> HTTP  {
        return try HTTP.New(url, method: .PATCH, parameters: parameters, headers: headers, requestSerializer: requestSerializer)
    }
    
    /**
     Class method to create a Download request that handles the NSMutableURLRequest and parameter encoding for you.
     */
    open class func Download(_ url: String, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil,
                             requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer(), completion:@escaping ((URL) -> Void)) throws -> HTTP  {
        let task = try HTTP.New(url, method: .GET, parameters: parameters, headers: headers, requestSerializer: requestSerializer, isDownload: true)
        task.downloadHandler = completion
        return task
    }
    
    /**
    Class method to create a HTTP request that handles the NSMutableURLRequest and parameter encoding for you.
    */
    open class func New(_ url: String, method: HTTPVerb, parameters: HTTPParameterProtocol? = nil, headers: [String:String]? = nil, requestSerializer: HTTPSerializeProtocol = HTTPParameterSerializer(), isDownload: Bool = false) throws -> HTTP  {
        guard let req = NSMutableURLRequest(urlString: url) else { throw HTTPOptError.invalidRequest }
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
        return HTTP(req as URLRequest, isDownload: isDownload)
    }
    
    /**
    Set the global auth handler
    */
    open class func globalAuth(_ handler: ((URLAuthenticationChallenge) -> URLCredential?)?) {
        DelegateManager.sharedInstance.auth = handler
    }
    
    /**
    Set the global security handler
    */
    open class func globalSecurity(_ security: HTTPSecurity?) {
        DelegateManager.sharedInstance.security = security
    }
    
    /**
    Set the global request handler
    */
    open class func globalRequest(_ handler: ((NSMutableURLRequest) -> Void)?) {
        DelegateManager.sharedInstance.requestHandler = handler
    }
}

// Simple operator functions to simplify the assertions used above.
private func <(lhs: HTTP.State, rhs: HTTP.State) -> Bool {
	return lhs.rawValue < rhs.rawValue
}

private func ==(lhs: HTTP.State, rhs: HTTP.State) -> Bool {
	return lhs.rawValue == rhs.rawValue
}

// Lock for getting / setting state safely
extension NSLock {
	func withCriticalScope<T>(_ block: (Void) -> T) -> T {
		lock()
		let value = block()
		unlock()
		return value
	}
}

/**
Absorb all the delegates methods of NSURLSession and forwards them to pretty closures.
This is basically the sin eater for NSURLSession.
*/
public class DelegateManager: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
    //the singleton to handle delegate needs of NSURLSession
    static let sharedInstance = DelegateManager()
    
    /// this is for global authenication handling
    var auth:((URLAuthenticationChallenge) -> URLCredential?)?
    
    ///This is for global SSL pinning
    var security: HTTPSecurity?
    
    /// this is for global request handling
    var requestHandler:((NSMutableURLRequest) -> Void)?
    
    var taskMap = Dictionary<Int,Response>()
    //"install" a task by adding the task to the map and setting the completion handler
    func addTask(_ task: URLSessionTask, completionHandler:@escaping ((Response) -> Void)) {
        addResponseForTask(task)
        if let resp = responseForTask(task) {
            resp.completionHandler = completionHandler
        }
    }
    
    //"remove" a task by removing the task from the map
    func removeTask(_ task: URLSessionTask) {
        taskMap.removeValue(forKey: task.taskIdentifier)
    }
    
    //add the response task
    func addResponseForTask(_ task: URLSessionTask) {
        if taskMap[task.taskIdentifier] == nil {
            taskMap[task.taskIdentifier] = Response()
        }
    }
    //get the response object for the task
    func responseForTask(_ task: URLSessionTask) -> Response? {
        return taskMap[task.taskIdentifier]
    }
    
    //handle getting data
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        addResponseForTask(dataTask)
        guard let resp = responseForTask(dataTask) else { return }
        resp.collectData.append(data)
        if resp.progressHandler != nil { //don't want the extra cycles for no reason
            guard let taskResp = dataTask.response else { return }
            progressHandler(resp, expectedLength: taskResp.expectedContentLength, currentLength: Int64(resp.collectData.length))
        }
    }
    
    //handle task finishing
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let resp = responseForTask(task) else { return }
        resp.error = error as NSError?
        if let hresponse = task.response as? HTTPURLResponse {
            resp.headers = hresponse.allHeaderFields as? Dictionary<String,String>
            resp.mimeType = hresponse.mimeType
            resp.suggestedFilename = hresponse.suggestedFilename
            resp.statusCode = hresponse.statusCode
            resp.URL = hresponse.url
        }
        if let code = resp.statusCode , resp.statusCode > 299 {
            resp.error = createError(code)
        }
        if let handler = resp.completionHandler {
            handler(resp)
        }
        removeTask(task)
    }
    
    //handle authenication
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
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
        if let sec = sec , challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let space = challenge.protectionSpace
            if let trust = space.serverTrust {
                if sec.isValid(trust, domain: space.host) {
                    completionHandler(.useCredential, URLCredential(trust: trust))
                    return
                }
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
            
        } else if let a = au {
            let cred = a(challenge)
            if let c = cred {
                completionHandler(.useCredential, c)
                return
            }
            completionHandler(.rejectProtectionSpace, nil)
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    //upload progress
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let resp = responseForTask(task) else { return }
        progressHandler(resp, expectedLength: totalBytesExpectedToSend, currentLength: totalBytesSent)
    }
    
    //download progress
    public func urlSession(_ session: Foundation.URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let resp = responseForTask(downloadTask) else { return }
        progressHandler(resp, expectedLength: totalBytesExpectedToWrite, currentLength: bytesWritten)
    }
    
    //handle download task
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let resp = responseForTask(downloadTask) else { return }
        guard let handler = resp.downloadHandler else { return }
        handler(location)
    }
    
    //handle progress
    public func progressHandler(_ response: Response, expectedLength: Int64, currentLength: Int64) {
        guard let handler = response.progressHandler else { return }
        let slice = Float(1.0)/Float(expectedLength)
        handler(slice*Float(currentLength))
    }
    
    /**
    Create an error for response you probably don't want (400-500 HTTP responses for example).
    
    -parameter code: Code for error.
    
    -returns An NSError.
    */
    fileprivate func createError(_ code: Int) -> NSError {
        let text = HTTPStatusCode(statusCode: code).statusDescription
        return NSError(domain: "HTTP", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

/**
Handles providing singletons of NSURLSession.
*/
class SharedSession {
    static let defaultSession = URLSession(configuration: URLSessionConfiguration.default,
        delegate: DelegateManager.sharedInstance, delegateQueue: nil)
    static let ephemeralSession = URLSession(configuration: URLSessionConfiguration.ephemeral,
        delegate: DelegateManager.sharedInstance, delegateQueue: nil)
}
