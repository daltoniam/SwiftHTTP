//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPResponseSerializer.swift
//
//  Created by Dalton Cherry on 6/16/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

protocol HTTPResponseSerializer {
    
    func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?)
}

struct JSONResponseSerializer : HTTPResponseSerializer {
    func responseObjectFromResponse(response: NSURLResponse, data: NSData) -> (object: AnyObject?, error: NSError?) {
        var error: NSError?
        let response: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(), error: &error)
        return (response,error)
    }
}

