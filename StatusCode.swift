//
//  HTTPStatusCode.swift
//  SwiftHTTP
//
//  Created by Yu Kadowaki on 7/12/15.
//  Copyright (c) 2015 Vluxe. All rights reserved.
//

import Foundation

/// HTTP Status Code (RFC 2616)
public enum HTTPStatusCode: Int {
    case Continue = 100,
    SwitchingProtocols = 101
    
    case OK = 200,
    Created = 201,
    Accepted = 202,
    NonAuthoritativeInformation = 203,
    NoContent = 204,
    ResetContent = 205,
    PartialContent = 206
    
    case MultipleChoices = 300,
    MovedPermanently = 301,
    Found = 302,
    SeeOther = 303,
    NotModified = 304,
    UseProxy = 305,
    Unused = 306,
    TemporaryRedirect = 307
    
    case BadRequest = 400,
    Unauthorized = 401,
    PaymentRequired = 402,
    Forbidden = 403,
    NotFound = 404,
    MethodNotAllowed = 405,
    NotAcceptable = 406,
    ProxyAuthenticationRequired = 407,
    RequestTimeout = 408,
    Conflict = 409,
    Gone = 410,
    LengthRequired = 411,
    PreconditionFailed = 412,
    RequestEntityTooLarge = 413,
    RequestUriTooLong = 414,
    UnsupportedMediaType = 415,
    RequestedRangeNotSatisfiable = 416,
    ExpectationFailed = 417
    
    case InternalServerError = 500,
    NotImplemented = 501,
    BadGateway = 502,
    ServiceUnavailable = 503,
    GatewayTimeout = 504,
    HttpVersionNotSupported = 505
    
    case InvalidUrl = -1001
    
    case UnknownStatus = 0
    
    init(statusCode: Int) {
        self = HTTPStatusCode(rawValue: statusCode) ?? .UnknownStatus
    }
    
    public var statusDescription: String {
        get {
            switch self {
            case .Continue:
                return "Continue"
            case .SwitchingProtocols:
                return "Switching protocols"
            case .OK:
                return "OK"
            case .Created:
                return "Created"
            case .Accepted:
                return "Accepted"
            case .NonAuthoritativeInformation:
                return "Non authoritative information"
            case .NoContent:
                return "No content"
            case .ResetContent:
                return "Reset content"
            case .PartialContent:
                return "Partial Content"
            case .MultipleChoices:
                return "Multiple choices"
            case .MovedPermanently:
                return "Moved Permanently"
            case .Found:
                return "Found"
            case .SeeOther:
                return "See other Uri"
            case .NotModified:
                return "Not modified"
            case .UseProxy:
                return "Use proxy"
            case .Unused:
                return "Unused"
            case .TemporaryRedirect:
                return "Temporary redirect"
            case .BadRequest:
                return "Bad request"
            case .Unauthorized:
                return "Access denied"
            case .PaymentRequired:
                return "Payment required"
            case .Forbidden:
                return "Forbidden"
            case .NotFound:
                return "Page not found"
            case .MethodNotAllowed:
                return "Method not allowed"
            case .NotAcceptable:
                return "Not acceptable"
            case .ProxyAuthenticationRequired:
                return "Proxy authentication required"
            case .RequestTimeout:
                return "Request timeout"
            case .Conflict:
                return "Conflict request"
            case .Gone:
                return "Page is gone"
            case .LengthRequired:
                return "Lack content length"
            case .PreconditionFailed:
                return "Precondition failed"
            case .RequestEntityTooLarge:
                return "Request entity is too large"
            case .RequestUriTooLong:
                return "Request uri is too long"
            case .UnsupportedMediaType:
                return "Unsupported media type"
            case .RequestedRangeNotSatisfiable:
                return "Request range is not satisfiable"
            case .ExpectationFailed:
                return "Expected request is failed"
            case .InternalServerError:
                return "Internal server error"
            case .NotImplemented:
                return "Server does not implement a feature for request"
            case .BadGateway:
                return "Bad gateway"
            case .ServiceUnavailable:
                return "Service unavailable"
            case .GatewayTimeout:
                return "Gateway timeout"
            case .HttpVersionNotSupported:
                return "Http version not supported"
            case .InvalidUrl:
                return "Invalid url"
            default:
                return "Unknown status code"
            }
        }
    }
}