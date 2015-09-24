//
//  Upload.swift
//  SwiftHTTP
//
//  Created by Dalton Cherry on 6/5/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//

import Foundation

#if os(iOS)
    import MobileCoreServices
#endif

/**
Upload errors
*/
enum HTTPUploadError: ErrorType {
    case NoFileUrl
}


/**
This is how to upload files in SwiftHTTP. The upload object represents a file to upload by either a data blob or a url (which it reads off disk).
*/
public class Upload: NSObject, NSCoding {
    var fileUrl: NSURL? {
        didSet {
            getMimeType()
        }
    }
    var mimeType: String?
    var data: NSData?
    var fileName: String?
    
    /**
    Tries to determine the mime type from the fileUrl extension.
    */
    func getMimeType() {
        mimeType = "application/octet-stream"
        guard let url = fileUrl else { return }
        #if os(iOS) || os(OSX) //for watchOS support
        if let ext = url.pathExtension  {
            guard let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, nil) else { return }
            guard let str = UTTypeCopyPreferredTagWithClass(UTI.takeRetainedValue(), kUTTagClassMIMEType) else { return }
            mimeType = str.takeRetainedValue() as String
        }
        #endif
    }
    
    /**
    Reads the data from disk or from memory. Throws an error if no data or file is found.
    */
    public func getData() throws -> NSData {
        if let d = data {
            return d
        }
        guard let url = fileUrl else { throw HTTPUploadError.NoFileUrl }
        fileName = url.lastPathComponent
        let d = try NSData(contentsOfURL: url, options: NSDataReadingOptions.DataReadingMappedIfSafe)
        data = d
        return d
    }
    
    /**
    Standard NSCoder support
    */
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.fileUrl, forKey: "fileUrl")
        aCoder.encodeObject(self.mimeType, forKey: "mimeType")
        aCoder.encodeObject(self.fileName, forKey: "fileName")
        aCoder.encodeObject(self.data, forKey: "data")
    }
    
    /**
    Required for NSObject support (because of NSCoder, it would be a struct otherwise!)
    */
    public override init() {
        super.init()
    }
    
    required public convenience init(coder aDecoder: NSCoder) {
        self.init()
        fileUrl = aDecoder.decodeObjectForKey("fileUrl") as? NSURL
        mimeType = aDecoder.decodeObjectForKey("mimeType") as? String
        fileName = aDecoder.decodeObjectForKey("fileName") as? String
        data = aDecoder.decodeObjectForKey("data") as? NSData
    }
    
    /**
    Initializes a new Upload object with a fileUrl. The fileName and mimeType will be infered.
    
    -parameter fileUrl: The fileUrl is a standard url path to a file.
    */
    public convenience init(fileUrl: NSURL) {
        self.init()
        self.fileUrl = fileUrl
    }
    
    /**
    Initializes a new Upload object with a data blob.
    
    -parameter data: The data is a NSData representation of a file's data.
    -parameter fileName: The fileName is just that. The file's name.
    -parameter mimeType: The mimeType is just that. The mime type you would like the file to uploaded as.
    */
    ///upload a file from a a data blob. Must add a filename and mimeType as that can't be infered from the data
    public convenience init(data: NSData, fileName: String, mimeType: String) {
        self.init()
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}
