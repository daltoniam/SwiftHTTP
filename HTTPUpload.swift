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
            var UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileUrl?.pathExtension, nil);
            var str = UTTypeCopyPreferredTagWithClass(UTI.takeUnretainedValue(), kUTTagClassMIMEType);
            if !str {
                mimeType = "application/octet-stream";
            } else {
                mimeType = str.takeUnretainedValue()
            }
        }
    }
    ///upload a file with a fileUrl. The fileName and mimeType will be infered
    class func uploadWithFile(fileUrl: NSURL) -> (HTTPUpload) {
        var upload = HTTPUpload()
        upload.fileUrl = fileUrl
        return upload
    }
    ///upload a file from a a data blob. Must add a filename and mimeType as that can't be infered from the data
    class func uploadWithData(data: NSData, fileName: String, mimeType: String) -> (HTTPUpload) {
        var upload = HTTPUpload()
        upload.data = data
        upload.fileName = fileName
        upload.mimeType = mimeType
        return upload
    }
}
