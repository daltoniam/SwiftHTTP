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
    
    func escapeStr() -> String {
        var raw: NSString = self
        var str = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,raw,"[].",":/?&=;+!@#$()',*",CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
        return str as NSString
    }
}

class HTTPRequestSerializer: NSObject {
    var headers = Dictionary<String,String>()
    var stringEncoding: UInt = NSUTF8StringEncoding
    var allowsCellularAccess = true
    var HTTPShouldHandleCookies = true
    var HTTPShouldUsePipelining = false
    var timeoutInterval: NSTimeInterval = 60
    var cachePolicy: NSURLRequestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
    var networkServiceType = NSURLRequestNetworkServiceType.NetworkServiceTypeDefault
    let contentTypeKey = "Content-Type"
    
    init() {
        super.init()
    }
    func newRequest(url: NSURL, method: HTTPMethod) -> NSMutableURLRequest {
        var request = NSMutableURLRequest(URL: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        request.HTTPMethod = method.toRaw()
        request.allowsCellularAccess = self.allowsCellularAccess
        request.HTTPShouldHandleCookies = self.HTTPShouldHandleCookies
        request.HTTPShouldUsePipelining = self.HTTPShouldUsePipelining
        request.networkServiceType = self.networkServiceType
        for (key,val) in self.headers {
            request.addValue(val, forHTTPHeaderField: key)
        }
        return request
    }
    ///creates a request from the url, HTTPMethod, and parameters
    func createRequest(url: NSURL, method: HTTPMethod, parameters: Dictionary<String,AnyObject>?) -> (request: NSURLRequest, error: NSError?) {
        
        var request = newRequest(url, method: method)
        var isMultiForm = false
        //do a check for upload objects to see if we are multi form
        if let params = parameters {
            for (name,object: AnyObject) in params {
                if object is HTTPUpload {
                    isMultiForm = true
                    break
                }
            }
        }
        if isMultiForm {
            if(method != HTTPMethod.POST || method != HTTPMethod.PUT) {
                request.HTTPMethod = HTTPMethod.POST.toRaw() // you probably wanted a post
            }
            if parameters {
                request.HTTPBody = dataFromParameters(parameters!)
            }
            return (request,nil)
        }
        var queryString = ""
        if parameters {
            queryString = self.stringFromParameters(parameters!)
        }
        if isURIParam(method) {
            var para = request.URL.query ? "&" : "?"
            var newUrl = "\(request.URL.absoluteString)\(para)\(queryString)"
            request.URL = NSURL.URLWithString(newUrl)
        } else {
            var charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.stringEncoding));
            if !request.valueForHTTPHeaderField(contentTypeKey) {
                request.setValue("application/x-www-form-urlencoded; charset=\(charset)",
                    forHTTPHeaderField:contentTypeKey)
            }
            request.HTTPBody = queryString.dataUsingEncoding(self.stringEncoding)
        }
        return (request,nil)
    }
    
    ///convert the parameter dict to its HTTP string representation
    func stringFromParameters(parameters: Dictionary<String,AnyObject>) -> String {
        return join("&", map(serializeObject(parameters, key: nil), {(pair) in
            return pair.stringValue()
            }))
    }
    ///check if enum is a HTTPMethod that requires the params in the URL
    func isURIParam(method: HTTPMethod) -> Bool {
        if(method == HTTPMethod.GET || method == HTTPMethod.HEAD || method == HTTPMethod.DELETE) {
            return true
        }
        return false
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
                var newKey = key ? "\(key!)[\(nestedKey)]" : nestedKey
                collect.extend(self.serializeObject(nestedObject,key: newKey))
            }
        } else {
            collect.append(HTTPPair(value: object, key: key))
        }
        return collect
    }
    //create a multi form data object of the parameters
    func dataFromParameters(parameters: Dictionary<String,AnyObject>) -> NSData {
        var mutData = NSMutableData()
        var files = Dictionary<String,HTTPUpload>()
        var notFiles = Dictionary<String,AnyObject>()
        for (key, object: AnyObject) in parameters {
            if let upload = object as? HTTPUpload {
                files[key] = upload
            } else {
                notFiles[key] = object
            }
        }
        var multiCRLF = "\r\n"
        var boundary = "Boundary+\(arc4random())\(arc4random())"
        var boundSplit = "\(multiCRLF)--\(boundary)\(multiCRLF)"
        mutData.appendData("--\(boundary)\(multiCRLF)".dataUsingEncoding(self.stringEncoding))
        var noParams = false
        if notFiles.count == 0 {
            noParams = true
        }
        var i = files.count
        for (key,upload) in files {
            mutData.appendData(multiFormHeader(key, fileName: upload.fileName,
                type: upload.mimeType, multiCRLF: multiCRLF).dataUsingEncoding(self.stringEncoding))
            mutData.appendData(upload.data)
            if i == 1 && noParams {
            } else {
                mutData.appendData(boundSplit.dataUsingEncoding(self.stringEncoding))
            }
        }
        if !noParams {
            let paramStr = join(boundSplit, map(serializeObject(notFiles, key: nil), {(pair) in
                return "\(self.multiFormHeader(pair.key, fileName: nil, type: nil, multiCRLF: multiCRLF))\(pair.getValue())"
                }))
            mutData.appendData(paramStr.dataUsingEncoding(self.stringEncoding))
        }
        mutData.appendData("\(multiCRLF)--\(boundary)--\(multiCRLF)".dataUsingEncoding(self.stringEncoding))
        return mutData
    }
    ///helper method to create the multi form headers
    func multiFormHeader(name: String, fileName: String?, type: String?, multiCRLF: String) -> String {
        var str = "Content-Disposition: form-data; name=\"\(name.escapeStr())\""
        if fileName {
            str += "; filename=\"\(fileName)\""
        }
        str += multiCRLF
        if type {
            str += "Content-Type: \"\(type)\"\(multiCRLF)"
        }
        str += multiCRLF
        return str
    }
    ///Local class to create key/pair of the parameters
    class HTTPPair: NSObject {
        var value: AnyObject
        var key: String!
        
        init(value: AnyObject, key: String?) {
            self.value = value
            self.key = key
        }
        func getValue() -> String {
            var val = ""
            if let str = self.value as? String {
                val = str
            } else if self.value.description {
                val = self.value.description
            }
            return val
        }
        func stringValue() -> String {
            var val = getValue()
            if !self.key {
                return val.escapeStr()
            }
            return "\(self.key.escapeStr())=\(val.escapeStr())"
        }
        
    }
   
}

class JSONRequestSerializer: HTTPRequestSerializer {
    
    override func createRequest(url: NSURL, method: HTTPMethod, parameters: Dictionary<String,AnyObject>?) -> (request: NSURLRequest, error: NSError?) {
        if self.isURIParam(method) {
            return super.createRequest(url, method: method, parameters: parameters)
        }
        var request = newRequest(url, method: method)
        var error: NSError?
        if parameters {
            var charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
            request.setValue("application/json; charset=\(charset)", forHTTPHeaderField: self.contentTypeKey)
            request.HTTPBody = NSJSONSerialization.dataWithJSONObject(parameters, options: NSJSONWritingOptions(), error:&error)
        }
        return (request, error)
    }
    
}
