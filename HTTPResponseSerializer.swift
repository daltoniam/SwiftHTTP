//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPResponseSerializer.swift
//
//  Created by Dalton Cherry on 6/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

public protocol HTTPResponseSerializer {
    //This can be used if you want to have your data parsed/serialized into something instead of just a NSData blob.
    func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?)
}
//Serialize the data into a JSON object
public struct JSONResponseSerializer : HTTPResponseSerializer {
    public init(){}
    
    public func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?) {
        var error: NSError?
        let response: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(), error: &error)
        return (response,error)
    }
}

