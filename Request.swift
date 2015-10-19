//
//  Request.swift
//  SwiftHTTP
//
//  Created by Dalton Cherry on 8/16/15.
//  Copyright © 2015 vluxe. All rights reserved.
//

import Foundation


extension String {
    /**
    A simple extension to the String object to encode it for web request.
    
    :returns: Encoded version of of string it was called as.
    */
    var escaped: String? {
        let set = NSMutableCharacterSet()
        set.formUnionWithCharacterSet(NSCharacterSet.URLQueryAllowedCharacterSet())
        set.removeCharactersInString("[].:/?&=;+!@#$()',*\"") // remove the HTTP ones from the set.
        return self.stringByAddingPercentEncodingWithAllowedCharacters(set)
    }
}

/**
The standard HTTP Verbs
*/
public enum HTTPVerb: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
    case OPTIONS = "OPTIONS"
    case TRACE = "TRACE"
    case CONNECT = "CONNECT"
    case UNKNOWN = "UNKNOWN"
}

/**
This is used to create key/value pairs of the parameters
*/
public struct HTTPPair {
    var key: String?
    let storeVal: AnyObject
    /**
    Create the object with a possible key and a value
    */
    init(key: String?, value: AnyObject) {
        self.key = key
        self.storeVal = value
    }
    /**
    Computed property of the string representation of the storedVal
    */
    var upload: Upload? {
        return storeVal as? Upload
    }
    /**
    Computed property of the string representation of the storedVal
    */
    var value: String {
        if let v = storeVal as? String {
            return v
        } else if let v = storeVal.description {
            return v
        }
        return ""
    }
    /**
    Computed property of the string representation of the storedVal escaped for URLs
    */
    var escapedValue: String {
        if let v = value.escaped {
            if let k = key {
                if let escapedKey = k.escaped {
                    return "\(escapedKey)=\(v)"
                }
            }
            return v
        }
        return ""
    }
}

/**
Enum used to describe what kind of Parameter is being interacted with.
This allows us to only support an Array or Dictionary and avoid having to use AnyObject
*/
public enum HTTPParamType {
    case Array
    case Dictionary
    case Upload
}

/**
This protocol is used to make the dictionary and array serializable into key/value pairs.
*/
public protocol HTTPParameterProtocol {
    func paramType() -> HTTPParamType
    func createPairs(key: String?) -> Array<HTTPPair>
}

/**
Support for the Dictionary type as an HTTPParameter.
*/
extension Dictionary: HTTPParameterProtocol {
    public func paramType() -> HTTPParamType {
        return .Dictionary
    }
    public func createPairs(key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        for (k, v) in self {
            if let nestedKey = k as? String, let nestedVal = v as? AnyObject {
                let useKey = key != nil ? "\(key!)[\(nestedKey)]" : nestedKey
                if let subParam = nestedVal as? Dictionary { //as? HTTPParameterProtocol <- bug? should work.
                    collect.appendContentsOf(subParam.createPairs(useKey))
                } else if let subParam = nestedVal as? Array<AnyObject> {
                    collect.appendContentsOf(subParam.createPairs(useKey))
                } else {
                    collect.append(HTTPPair(key: useKey, value: nestedVal))
                }
            }
        }
        return collect
    }
}

/**
Support for the Array type as an HTTPParameter.
*/
extension Array: HTTPParameterProtocol {
    public func paramType() -> HTTPParamType {
        return .Array
    }
    
    public func createPairs(key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        for v in self {
            if let nestedVal = v as? AnyObject {
                let useKey = key != nil ? "\(key!)[]" : key
                if let subParam = nestedVal as? Dictionary<String, AnyObject> {
                    collect.appendContentsOf(subParam.createPairs(useKey))
                } else if let subParam = nestedVal as? Array<AnyObject> {
                    collect.appendContentsOf(subParam.createPairs(useKey))
                } else {
                    collect.append(HTTPPair(key: useKey, value: nestedVal))
                }
            }
        }
        return collect
    }
}

/**
Support for the Upload type as an HTTPParameter.
*/
extension Upload: HTTPParameterProtocol {
    public func paramType() -> HTTPParamType {
        return .Upload
    }
    
    public func createPairs(key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        collect.append(HTTPPair(key: key, value: self))
        return collect
    }
}

/**
Adds convenience methods to NSMutableURLRequest to make using it with HTTP much simpler.
*/
extension NSMutableURLRequest {
    /**
    Convenience init to allow init with a string.
    -parameter urlString: The string representation of a URL to init with.
    */
    public convenience init?(urlString: String) {
        if let url = NSURL(string: urlString) {
            self.init(URL: url)
        } else {
            return nil
        }
    }
    
    /**
    Convenience method to avoid having to use strings and allow using an enum
    */
    public var verb: HTTPVerb {
        set {
            HTTPMethod = newValue.rawValue
        }
        get {
            if let v = HTTPVerb(rawValue: HTTPMethod) {
                return v
            }
            return .UNKNOWN
        }
    }
    
    /**
    Used to update the content type in the HTTP header as needed
    */
    var contentTypeKey: String {
        return "Content-Type"
    }
    
    /**
    append the parameters using the standard HTTP Query model.
    This is parameters in the query string of the url (e.g. ?first=one&second=two for GET, HEAD, DELETE.
    It uses 'application/x-www-form-urlencoded' for the content type of POST/PUT requests that don't contains files.
    If it contains a file it uses `multipart/form-data` for the content type.
    -parameter parameters: The container (array or dictionary) to convert and append to the URL or Body
    */
    public func appendParameters(parameters: HTTPParameterProtocol) throws {
        if isURIParam() {
            appendParametersAsQueryString(parameters)
        } else if containsFile(parameters) {
            try appendParametersAsMultiPartFormData(parameters)
        } else {
            appendParametersAsUrlEncoding(parameters)
        }
    }
    
    /**
    append the parameters as a HTTP Query string. (e.g. domain.com?first=one&second=two)
    -parameter parameters: The container (array or dictionary) to convert and append to the URL
    */
    public func appendParametersAsQueryString(parameters: HTTPParameterProtocol) {
        let queryString = parameters.createPairs(nil).map({ (pair) in
            return pair.escapedValue
        }).joinWithSeparator("&")
        if let u = self.URL where queryString.characters.count > 0 {
            let para = u.query != nil ? "&" : "?"
            self.URL = NSURL(string: "\(u.absoluteString)\(para)\(queryString)")
        }
    }
    
    /**
    append the parameters as a url encoded string. (e.g. in the body of the request as: first=one&second=two)
    -parameter parameters: The container (array or dictionary) to convert and append to the HTTP body
    */
    public func appendParametersAsUrlEncoding(parameters: HTTPParameterProtocol) {
        if valueForHTTPHeaderField(contentTypeKey) == nil {
            let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
            setValue("application/x-www-form-urlencoded; charset=\(charset)",
                forHTTPHeaderField:contentTypeKey)
            
        }
        let queryString = parameters.createPairs(nil).map({ (pair) in
            return pair.escapedValue
        }).joinWithSeparator("&")
        HTTPBody = queryString.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    /**
    append the parameters as a multpart form body. This is the type normally used for file uploads.
    -parameter parameters: The container (array or dictionary) to convert and append to the HTTP body
    */
    public func appendParametersAsMultiPartFormData(parameters: HTTPParameterProtocol) throws {
        let boundary = "Boundary+\(arc4random())\(arc4random())"
        if valueForHTTPHeaderField(contentTypeKey) == nil {
            setValue("multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField:contentTypeKey)
        }
        let mutData = NSMutableData()
        let multiCRLF = "\r\n"
        mutData.appendData("--\(boundary)".dataUsingEncoding(NSUTF8StringEncoding)!)
        for pair in parameters.createPairs(nil) {
            guard let key = pair.key else { continue } //this won't happen, but just to properly unwrap
            mutData.appendData("\(multiCRLF)".dataUsingEncoding(NSUTF8StringEncoding)!)
            if let upload = pair.upload {
                let data = try upload.getData()
                mutData.appendData(multiFormHeader(key, fileName: upload.fileName,
                    type: upload.mimeType, multiCRLF: multiCRLF).dataUsingEncoding(NSUTF8StringEncoding)!)
                mutData.appendData(data)
            } else {
                let str = "\(multiFormHeader(key, fileName: nil, type: nil, multiCRLF: multiCRLF))\(pair.value)"
                mutData.appendData(str.dataUsingEncoding(NSUTF8StringEncoding)!)
            }
            mutData.appendData("\(multiCRLF)--\(boundary)".dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        mutData.appendData("--\(multiCRLF)".dataUsingEncoding(NSUTF8StringEncoding)!)
        HTTPBody = mutData
    }
    
    /**
    Helper method to create the multipart form data
    */
    func multiFormHeader(name: String, fileName: String?, type: String?, multiCRLF: String) -> String {
        var str = "Content-Disposition: form-data; name=\"\(name.escaped!)\""
        if let name = fileName {
            str += "; filename=\"\(name)\""
        }
        str += multiCRLF
        if let t = type {
            str += "Content-Type: \(t)\(multiCRLF)"
        }
        str += multiCRLF
        return str
    }
    
    
    /**
     send the parameters as a body of JSON
    -parameter parameters: The container (array or dictionary) to convert and append to the URL or Body
    */
    public func appendParametersAsJSON(parameters: HTTPParameterProtocol) throws {
        if isURIParam() {
            appendParametersAsQueryString(parameters)
        } else {
            do {
                HTTPBody = try NSJSONSerialization.dataWithJSONObject(parameters as! AnyObject, options: NSJSONWritingOptions())
            } catch let error {
                throw error
            }
            let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
            setValue("application/json; charset=\(charset)", forHTTPHeaderField: contentTypeKey)
        }
    }
    
     /**
    Check if the request requires the parameters to be appended to the URL
    */
    public func isURIParam() -> Bool {
        if verb == .GET || verb == .HEAD || verb == .DELETE {
            return true
        }
        return false
    }
    
    /**
     check if the parameters contain a file object within them
    -parameter parameters: The parameters to search through for an upload object
    */
    public func containsFile(parameters: Any) -> Bool {
        guard let params = parameters as? HTTPParameterProtocol else { return false }
        for pair in params.createPairs(nil) {
            if let _ = pair.upload {
                return true
            }
        }
        return false
    }
}
