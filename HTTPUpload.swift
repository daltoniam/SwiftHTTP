//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPUpload.swift
//
//  Created by Dalton Cherry on 6/5/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

#if os(iOS)
    import MobileCoreServices
#endif


/// Object representation of a HTTP File Upload.
public class HTTPUpload: NSObject {
    var fileUrl: NSURL? {
    didSet {
        updateMimeType()
        loadData()
    }
    }
    var mimeType: String?
    var data: NSData?
    var fileName: String?
    
    /// Tries to determine the mime type from the fileUrl extension.
    func updateMimeType() {
        if mimeType == nil && fileUrl != nil {
            var UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileUrl?.pathExtension as NSString?, nil);
            var str = UTTypeCopyPreferredTagWithClass(UTI.takeUnretainedValue(), kUTTagClassMIMEType);
            if (str == nil) {
                mimeType = "application/octet-stream";
            } else {
                mimeType = str.takeUnretainedValue() as String
            }
        }
    }
    
    /// loads the fileUrl into memory.
    func loadData() {
        if let url = fileUrl {
            self.fileName = url.lastPathComponent
            self.data = NSData(contentsOfURL: url, options: NSDataReadingOptions.DataReadingMappedIfSafe, error: nil)
        }
    }
    
    /// Initializes a new HTTPUpload Object.
    public override init() {
        super.init()
    }
    
    /** 
        Initializes a new HTTPUpload Object with a fileUrl. The fileName and mimeType will be infered.
    
        :param: fileUrl The fileUrl is a standard url path to a file.
    */
    public convenience init(fileUrl: NSURL) {
        self.init()
        self.fileUrl = fileUrl
        updateMimeType()
        loadData()
    }
    
    /**
    Initializes a new HTTPUpload Object with a data blob of a file. The fileName and mimeType will be infered if none are provided.
    
        :param: data The data is a NSData representation of a file's data.
        :param: fileName The fileName is just that. The file's name.
        :param: mimeType The mimeType is just that. The mime type you would like the file to uploaded as.
    */
    ///upload a file from a a data blob. Must add a filename and mimeType as that can't be infered from the data
    public convenience init(data: NSData, fileName: String, mimeType: String) {
        self.init()
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}
