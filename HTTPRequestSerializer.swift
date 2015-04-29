//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPRequestSerializer.swift
//
//  Created by Dalton Cherry on 6/3/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation


extension String {
    /**
        A simple extension to the String object to encode it for web request.
    
        :returns: Encoded version of of string it was called as.
    */
    var escaped: String {
        return CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,self,"[].",":/?&=;+!@#$()',*",CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) as! String
    }
}

/// Default Serializer for serializing an object to an HTTP request. This applies to form serialization, parameter encoding, etc.
public class HTTPRequestSerializer: NSObject {
    let contentTypeKey = "Content-Type"
    
    /// headers for the request.
    public var headers = Dictionary<String,String>()
    /// encoding for the request.
    public var stringEncoding: UInt = NSUTF8StringEncoding
    /// Send request if using cellular network or not. Defaults to true.
    public var allowsCellularAccess = true
    /// If the request should handle cookies of not. Defaults to true.
    public var HTTPShouldHandleCookies = true
    /// If the request should use piplining or not. Defaults to false.
    public var HTTPShouldUsePipelining = false
    /// How long the timeout interval is. Defaults to 60 seconds.
    public var timeoutInterval: NSTimeInterval = 60
    /// Set the request cache policy. Defaults to UseProtocolCachePolicy.
    public var cachePolicy: NSURLRequestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
    /// Set the network service. Defaults to NetworkServiceTypeDefault.
    public var networkServiceType = NSURLRequestNetworkServiceType.NetworkServiceTypeDefault
    
    /// Initializes a new HTTPRequestSerializer Object.
    public override init() {
        super.init()
    }
    
    /**
        Creates a new NSMutableURLRequest object with configured options.
        
        :param: url The url you would like to make a request to.
        :param: method The HTTP method/verb for the request.
    
        :returns: A new NSMutableURLRequest with said options.
    */
    public func newRequest(url: NSURL, method: HTTPMethod) -> NSMutableURLRequest {
        var request = NSMutableURLRequest(URL: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        request.HTTPMethod = method.rawValue
        request.cachePolicy = self.cachePolicy
        request.timeoutInterval = self.timeoutInterval
        request.allowsCellularAccess = self.allowsCellularAccess
        request.HTTPShouldHandleCookies = self.HTTPShouldHandleCookies
        request.HTTPShouldUsePipelining = self.HTTPShouldUsePipelining
        request.networkServiceType = self.networkServiceType
        for (key,val) in self.headers {
            request.addValue(val, forHTTPHeaderField: key)
        }
        return request
    }
    
    /**
        Creates a new NSMutableURLRequest object with configured options.
        
        :param: url The url you would like to make a request to.
        :param: method The HTTP method/verb for the request.
        :param: parameters The parameters are HTTP parameters you would like to send.
        
        :returns: A new NSMutableURLRequest with said options or an error.
    */
    public func createRequest(url: NSURL, method: HTTPMethod, parameters: Dictionary<String,AnyObject>?) -> (request: NSURLRequest, error: NSError?) {
        
        var request = newRequest(url, method: method)
        var isMulti = false
        //do a check for upload objects to see if we are multi form
        if let params = parameters {
            isMulti = isMultiForm(params)
        }
        if isMulti {
            if(method != .POST && method != .PUT && method != .PATCH) {
                request.HTTPMethod = HTTPMethod.POST.rawValue // you probably wanted a post
            }
            var boundary = "Boundary+\(arc4random())\(arc4random())"
            if parameters != nil {
                request.HTTPBody = dataFromParameters(parameters!,boundary: boundary)
            }
            if request.valueForHTTPHeaderField(contentTypeKey) == nil {
                request.setValue("multipart/form-data; boundary=\(boundary)",
                    forHTTPHeaderField:contentTypeKey)
            }
            return (request,nil)
        }
        var queryString = ""
        if parameters != nil {
            queryString = self.stringFromParameters(parameters!)
        }
        if isURIParam(method) {
            var para = (request.URL!.query != nil) ? "&" : "?"
            var newUrl = "\(request.URL!.absoluteString!)"
            if count(queryString) > 0 {
                newUrl += "\(para)\(queryString)"
            }
            request.URL = NSURL(string: newUrl)
        } else {
            var charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.stringEncoding));
            if request.valueForHTTPHeaderField(contentTypeKey) == nil {
                request.setValue("application/x-www-form-urlencoded; charset=\(charset)",
                    forHTTPHeaderField:contentTypeKey)
            }
            request.HTTPBody = queryString.dataUsingEncoding(self.stringEncoding)
        }
        return (request,nil)
    }
    
    ///check for multi form objects
    public func isMultiForm(params: Dictionary<String,AnyObject>) -> Bool {
        for (name,object: AnyObject) in params {
            if object is HTTPUpload {
                return true
            } else if let subParams = object as? Dictionary<String,AnyObject> {
                if isMultiForm(subParams) {
                    return true
                }
            }
        }
        return false
    }
    
    ///check if enum is a HTTPMethod that requires the params in the URL
    public func isURIParam(method: HTTPMethod) -> Bool {
        if(method == .GET || method == .HEAD || method == .DELETE) {
            return true
        }
        return false
    }
    
    ///convert the parameter dict to its HTTP string representation
    func stringFromParameters(parameters: Dictionary<String,AnyObject>) -> String {
        return join("&", map(serializeObject(parameters, key: nil), {(pair) in
            return pair.stringValue()
            }))
    }
    
    ///the method to serialized all the objects
    func serializeObject(object: AnyObject,key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        if let array = object as? Array<AnyObject> {
            for nestedValue : AnyObject in array {
                collect.extend(self.serializeObject(nestedValue,key: "\(key!)[]"))
            }
        } else if let dict = object as? Dictionary<String,AnyObject> {
            for (nestedKey, nestedObject: AnyObject) in dict {
                var newKey = key != nil ? "\(key!)[\(nestedKey)]" : nestedKey
                collect.extend(self.serializeObject(nestedObject,key: newKey))
            }
        } else {
            collect.append(HTTPPair(value: object, key: key))
        }
        return collect
    }
    
    //create a multi form data object of the parameters
    func dataFromParameters(parameters: Dictionary<String,AnyObject>,boundary: String) -> NSData {
        var mutData = NSMutableData()
        var multiCRLF = "\r\n"
        var boundSplit =  "\(multiCRLF)--\(boundary)\(multiCRLF)".dataUsingEncoding(self.stringEncoding)!
        var lastBound =  "\(multiCRLF)--\(boundary)--\(multiCRLF)".dataUsingEncoding(self.stringEncoding)!
        mutData.appendData("--\(boundary)\(multiCRLF)".dataUsingEncoding(self.stringEncoding)!)
        
        let pairs = serializeObject(parameters, key: nil)
        let count = pairs.count-1
        var i = 0
        for pair in pairs {
            var append = true
            if let upload = pair.getUpload() {
                 if let data = upload.data {
                    mutData.appendData(multiFormHeader(pair.k, fileName: upload.fileName,
                        type: upload.mimeType, multiCRLF: multiCRLF).dataUsingEncoding(self.stringEncoding)!)
                    mutData.appendData(data)
                } else {
                    append = false
                }
            } else {
                let str = "\(multiFormHeader(pair.k, fileName: nil, type: nil, multiCRLF: multiCRLF))\(pair.getValue())"
                mutData.appendData(str.dataUsingEncoding(self.stringEncoding)!)
            }
            if append {
                if i == count {
                    mutData.appendData(lastBound)
                } else {
                    mutData.appendData(boundSplit)
                }
            }
            i++
        }
        return mutData
    }
    
    ///helper method to create the multi form headers
    func multiFormHeader(name: String, fileName: String?, type: String?, multiCRLF: String) -> String {
        var str = "Content-Disposition: form-data; name=\"\(name.escaped)\""
        if fileName != nil {
            str += "; filename=\"\(fileName!)\""
        }
        str += multiCRLF
        if type != nil {
            str += "Content-Type: \(type!)\(multiCRLF)"
        }
        str += multiCRLF
        return str
    }
    
    /// Creates key/pair of the parameters.
    class HTTPPair: NSObject {
        var val: AnyObject
        var k: String!
        
        init(value: AnyObject, key: String?) {
            self.val = value
            self.k = key
        }
        
        func getUpload() -> HTTPUpload? {
            return self.val as? HTTPUpload
        }
        
        func getValue() -> String {
            var val = ""
            if let str = self.val as? String {
                val = str
            } else if self.val.description != nil {
                val = self.val.description
            }
            return val
        }
        
        func stringValue() -> String {
            var v = getValue()
            if self.k == nil {
                return v.escaped
            }
            return "\(self.k.escaped)=\(v.escaped)"
        }
        
    }
   
}

/// JSON Serializer for serializing an object to an HTTP request. Same as HTTPRequestSerializer, expect instead of HTTP form encoding it does JSON.
public class JSONRequestSerializer: HTTPRequestSerializer {
    
    /**
        Creates a new NSMutableURLRequest object with configured options.
        
        :param: url The url you would like to make a request to.
        :param: method The HTTP method/verb for the request.
        :param: parameters The parameters are HTTP parameters you would like to send.
        
        :returns: A new NSMutableURLRequest with said options or an error.
    */
    public override func createRequest(url: NSURL, method: HTTPMethod, parameters: Dictionary<String,AnyObject>?) -> (request: NSURLRequest, error: NSError?) {
        if self.isURIParam(method) {
            return super.createRequest(url, method: method, parameters: parameters)
        }
        var request = newRequest(url, method: method)
        var error: NSError?
        if parameters != nil {
            var charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
            request.setValue("application/json; charset=\(charset)", forHTTPHeaderField: self.contentTypeKey)
            request.HTTPBody = NSJSONSerialization.dataWithJSONObject(parameters!, options: NSJSONWritingOptions(), error:&error)
        }
        return (request, error)
    }
    
}
