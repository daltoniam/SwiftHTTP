//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPResponseSerializer.swift
//
//  Created by Dalton Cherry on 6/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

/// This protocol provides a way to implement a custom serializer.
public protocol HTTPResponseSerializer {
    /// This can be used if you want to have your data parsed/serialized into something instead of just a NSData blob.
    func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?)
}

/// Serialize the data into a JSON object.
public struct JSONResponseSerializer : HTTPResponseSerializer {
    /// Initializes a new JSONResponseSerializer Object.
    public init(){}
    
    /**
        Creates a HTTPOperation that can be scheduled on a NSOperationQueue. Called by convenience HTTP verb methods below.
        
        :param: response The NSURLResponse.
        :param: data The response data to be parsed into JSON.
        
        :returns: Returns a object from JSON data and an NSError if an error occured while parsing the data.
    */
    public func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?) {
        var error: NSError?
        let response: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(), error: &error)
        return (response,error)
    }
}
