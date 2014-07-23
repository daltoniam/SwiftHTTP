//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPUpload.swift
//
//  Created by Dalton Cherry on 6/5/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import MobileCoreServices

class HTTPUpload: NSObject {
    var fileUrl: NSURL? {
    didSet {
        updateMimeType()
    }
    }
    var mimeType: String?
    var data: NSData?
    var fileName: String?
    //gets the mimeType from the fileUrl, if possible
    func updateMimeType() {
        if !mimeType && fileUrl {
            var UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileUrl?.pathExtension as NSString?, nil);
            var str = UTTypeCopyPreferredTagWithClass(UTI.takeUnretainedValue(), kUTTagClassMIMEType);
            if !str {
                mimeType = "application/octet-stream";
            } else {
                mimeType = str.takeUnretainedValue() as NSString
            }
        }
    }
    //default init does nothing
    init()  {
    }
    ///upload a file with a fileUrl. The fileName and mimeType will be infered
    convenience init(fileUrl: NSURL) {
        self.init()
        self.fileUrl = fileUrl
    }
    ///upload a file from a a data blob. Must add a filename and mimeType as that can't be infered from the data
    convenience init(data: NSData, fileName: String, mimeType: String) {
        self.init()
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}
