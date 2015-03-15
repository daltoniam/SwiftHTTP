SwiftHTTP
=========

SwiftHTTP is a thin wrapper around NSURLSession in Swift to simplify HTTP requests.

## Features

- Convenient Closure APIs
- NSOperationQueue Support
- Parameter Encoding
- Custom Response Serializer
- Builtin JSON Response Serialization
- Upload/Download with Progress Closure
- Concise Codebase. Under 1000 LOC

Full article here: [http://vluxe.io/swifthttp.html](http://vluxe.io/swifthttp.html)

First thing is to import the framework. See the Installation instructions on how to add the framework to your project.

```swift
import SwiftHTTP
```

## Examples

### GET

The most basic request. By default an NSData object will be returned for the response.
```swift
var request = HTTPTask()
request.GET("http://vluxe.io", parameters: nil, success: {(response: HTTPResponse) in
    	if let data = response.responseObject as? NSData {
            let str = NSString(data: data, encoding: NSUTF8StringEncoding)
            println("response: \(str)") //prints the HTML of the page
        }
    },failure: {(error: NSError, response: HTTPResponse?) in
    	println("error: \(error)")
    })
```

We can also add parameters as with standard container objects and they will be properly serialized to their respective HTTP equivalent.

```swift
var request = HTTPTask()
request.GET("http://google.com", parameters: ["param": "param1", "array": ["first array element","second","third"], "num": 23], success: {(response: HTTPResponse) in
    println("response: \(response.responseObject!)")
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("error: \(error)")
    })
```

The `HTTPResponse` contains all the common HTTP response data, such as the responseObject of the data and the headers of the response.

### POST

A POST request is just as easy as a GET.

```swift
var request = HTTPTask()
//we have to add the explicit type, else the wrong type is inferred. See the vluxe.io article for more info.
let params: Dictionary<String,AnyObject> = ["param": "param1", "array": ["first array element","second","third"], "num": 23, "dict": ["someKey": "someVal"]]
request.POST("http://domain.com/create", parameters: params, success: {(response: HTTPResponse) in

    },failure: {(error: NSError, response: HTTPResponse?) in

    })
```

### PUT

PUT works the same as post. The example also include a file upload to do a multi form request.

```swift
let fileUrl = NSURL.fileURLWithPath("/Users/dalton/Desktop/file")!
var request = HTTPTask()
request.PUT("http://domain.com/1", parameters:  ["param": "hi", "something": "else", "key": "value","file": HTTPUpload(fileUrl: fileUrl!)], success: {(response: HTTPResponse) in
	//do stuff
    },failure: {(error: NSError, response: HTTPResponse?) in
	//error out on stuff
    })
```

The HTTPUpload object is use to represent files on disk or in memory file as data.

### DELETE

DELETE works the same as the GET.

```swift
var request = HTTPTask()
request.DELETE("http://domain.com/1", parameters: nil, success: {(response: HTTPResponse) in
    	println("DELETE was successful!")
    },failure: {(error: NSError, response: HTTPResponse?) in
    	 println("print the error: \(error)")
    })
```

### HEAD

HEAD works the same as the GET.

```swift
var request = HTTPTask()
request.HEAD("http://domain.com/image.png", parameters: nil, success: {(response: HTTPResponse) in
    	println("The file does exist!")
    },failure: {(error: NSError, response: HTTPResponse?) in
		println("File not found: \(error)")
    })
```

### Download

The download method uses the background download functionality of NSURLSession. It also has a progress closure to report the progress of the download.

```swift
var request = HTTPTask()
let downloadTask = request.download("http://vluxe.io/assets/images/logo.png", parameters: nil, progress: {(complete: Double) in
    println("percent complete: \(complete)")
    }, success: {(response: HTTPResponse) in
    println("download finished!")
    if response.responseObject != nil {
	    //we MUST copy the file from its temp location to a permanent location.
        if let url = response.responseObject as? NSURL {
            if let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first as? String {
                if let fileName = response.suggestedFilename {
                    if let newPath = NSURL(fileURLWithPath: "\(path)/\(fileName)") {
                        let fileManager = NSFileManager.defaultManager()
                        fileManager.removeItemAtURL(newPath, error: nil)
                        fileManager.moveItemAtURL(url, toURL: newPath, error:nil)
                    }
                }
            }
        }
    }

    } ,failure: {(error: NSError, response: HTTPResponse?) in
        println("failure")
})
```

Cancel the download.

```swift
if let t = downloadTask {
    t.cancel()
}
```

### Upload

File uploads can be done using the `HTTPUpload` object. All files to upload should be wrapped in a HTTPUpload object and added as a parameter.

```swift
let fileUrl = NSURL.fileURLWithPath("/Users/dalton/Desktop/file")!
var request = HTTPTask()
request.POST("http://domain.com/1/upload", parameters:  ["aParam": "aValue","file": HTTPUpload(fileUrl: fileUrl!)], success: {(response: HTTPResponse) in
	//do stuff
    },failure: {(error: NSError, response: HTTPResponse?) in
	//error out on stuff
    })
```
`HTTPUpload` comes in both a on disk fileUrl version and a NSData version.

### Custom Headers

Custom HTTP headers can be add to a request via the requestSerializer.

```swift
var request = HTTPTask()
request.requestSerializer = HTTPRequestSerializer()
request.requestSerializer.headers["someKey"] = "SomeValue" //example of adding a header value
```

### Authentication

SwiftHTTP supports authentication through [NSURLCredential](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCredential_Class/Reference/Reference.html). Currently only Basic Auth and Digest Auth have been tested.

```swift
var request = HTTPTask()
//the auth closures will continually be called until a successful auth or rejection
var attempted = false
request.auth = {(challenge: NSURLAuthenticationChallenge) in
    if !attempted {
        attempted = true
        return NSURLCredential(user: "user", password: "passwd", persistence: .ForSession)
    }
    return nil //auth failed, nil causes the request to be properly cancelled.
}
request.GET("http://httpbin.org/basic-auth/user/passwd", parameters: nil, success: {(response: HTTPResponse) in
    if response.responseObject != nil {
        println("winning!")
    }

    }, failure: {(error: NSError, response: HTTPResponse?) in
        println("failure.")
})
```

Self-Signed Certificate example:

```swift
var request = HTTPTask()
var attempted = false
request.auth = {(challenge: NSURLAuthenticationChallenge) in
    if !attempted {
        attempted = true
        return NSURLCredential(forTrust: challenge.protectionSpace.serverTrust)
    }
    return nil
}
request.GET("https://somedomain.com", parameters: nil, success: {(response: HTTPResponse) in
    if response.responseObject != nil {
        println("winning!")
    }

    }, failure: {(error: NSError, response: HTTPResponse?) in
        println("failure.")
})
```


### BaseURL

SwiftHTTP also supports use a request object with a baseURL. This is super handy for RESTFul API interaction.

```swift
var request = HTTPTask()
request.baseURL = "http://api.someserver.com/1"
request.GET("/users", parameters: ["key": "value"], success: {(response: HTTPResponse) in
    println("Got data from http://api.someserver.com/1/users")
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("print the error: \(error)")
    })

request.POST("/users", parameters: ["key": "updatedVale"], success: {(response: HTTPResponse) in
    println("Got data from http://api.someserver.com/1/users")
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("print the error: \(error)")
    })

request.GET("/resources", parameters: ["key": "value"], success: {(response: HTTPResponse) in
    println("Got data from http://api.someserver.com/1/resources")
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("print the error: \(error)")
    })
```

### Operation Queue

Operation queues are also supported in SwiftHTTP.

```swift
let operationQueue = NSOperationQueue()
operationQueue.maxConcurrentOperationCount = 2
var request = HTTPTask()
var opt = request.create("http://vluxe.io", method: .GET, parameters: nil, success: {(response: HTTPResponse) in
    if let data = response.responseObject as? NSData {
        let str = NSString(data: data, encoding: NSUTF8StringEncoding)
        println("response: \(str)") //prints the HTML of the page
    }
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("error: \(error)")
})
if let o = opt {
    operationQueue.addOperation(o)
}
```

### Cancel

Let's say you want to cancel this request a little later, simple use the operationQueue cancel.

```swift
if let o = opt {
    o.cancel()
}
```

### Serializers

Request parameters and request responses can also be serialized as needed. By default request are serialized using standard HTTP form encoding. A JSON request and response serializer are provided as well. It is also very simple to create custom serializer by subclass a request or response serializer

```swift
var request = HTTPTask()
//The parameters will be encoding as JSON data and sent.
request.requestSerializer = JSONRequestSerializer()
//The expected response will be JSON and be converted to an object return by NSJSONSerialization instead of a NSData.
request.responseSerializer = JSONResponseSerializer()
request.GET("http://vluxe.io", parameters: nil, success: {(response: HTTPResponse) in
    	if let dict = response.responseObject as? Dictionary<String,AnyObject> {
			println("example of the JSON key: \(dict["key"])")
			println("print the whole response: \(response)")
        }
    },failure: {(error: NSError, response: HTTPResponse?) in
    	println("error: \(error)")
    })
```

## Client/Server Example

This is a full example swiftHTTP in action. First here is a quick web server in Go.

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/bar", func(w http.ResponseWriter, r *http.Request) {
		log.Println("got a web request")
		fmt.Println("header: ", r.Header.Get("someKey"))
		w.Write([]byte("{\"status\": \"ok\"}"))
	})

	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Now for the request:

```swift
//The object that will represent our response. More Info in the JSON Parsing section below.
struct Status : JSONJoy {
    var status: String?
    init() {

    }
    init(_ decoder: JSONDecoder) {
        status = decoder["status"].string
    }
}
//The request
var request = HTTPTask()
request.requestSerializer = HTTPRequestSerializer()
request.requestSerializer.headers["someKey"] = "SomeValue" //example of adding a header value
request.responseSerializer = JSONResponseSerializer()
request.GET("http://localhost:8080/bar", parameters: nil, success: {(response: HTTPResponse) in
    if response.responseObject != nil {
		let resp = Status(JSONDecoder(response.responseObject!))
        println("status is: \(resp.status)")
    }
    }, failure: {(error: NSError, response: HTTPResponse?) in
        println("got an error: \(error)")
})
```

## JSON Parsing

Swift has a lot of great JSON parsing libraries, but I made one specifically designed for JSON to object serialization.

[JSONJoy-Swift](https://github.com/daltoniam/JSONJoy-Swift)

## Requirements

SwiftHTTP works with iOS 7/OSX 10.9 or above. It is recommended to use iOS 8/10.10 or above for Cocoapods/framework support.

## Installation

### Cocoapods

Check out [Get Started](http://cocoapods.org/) tab on [cocoapods.org](http://cocoapods.org/).

To use SwiftHTTP in your project add the following 'Podfile' to your project

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '8.0'
	use_frameworks!

	pod 'SwiftHTTP', '~> 0.9.2'

Then run:

    pod install

### Carthage

Check out the [Carthage](https://github.com/Carthage/Carthage) docs on how to add a install. The `SwiftHTTP` framework is already setup with shared schemes.

[Carthage Install](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)

### Rogue

First see the [installation docs](https://github.com/acmacalister/Rogue) for how to install Rogue.

To install SwiftLog run the command below in the directory you created the rogue file.

```
rogue add https://github.com/daltoniam/SwiftHTTP
```

Next open the `libs` folder and add the `SwiftHTTP.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `SwiftHTTP.framework` to your "Link Binary with Libraries" phase. Make sure to add the `libs` folder to your `.gitignore` file.

### Other

Simply grab the framework (either via git submodule or another package manager).

Add the `SwiftHTTP.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `SwiftHTTP.framework` to your "Link Binary with Libraries" phase.

### Add Copy Frameworks Phase

If you are running this in an OSX app or on a physical iOS device you will need to make sure you add the `SwiftHTTP.framework` or `SwiftHTTPOSX.framework` to be included in your app bundle. To do this, in Xcode, navigate to the target configuration window by clicking on the blue project icon, and selecting the application target under the "Targets" heading in the sidebar. In the tab bar at the top of that window, open the "Build Phases" panel. Expand the "Link Binary with Libraries" group, and add `SwiftHTTP.framework` or `SwiftHTTPOSX.framework` depending on if you are building an iOS or OSX app. Click on the + button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `SwiftHTTP.framework` or `SwiftHTTPOSX.framework` respectively.

## TODOs

- [ ] Complete Docs
- [ ] Add Unit Tests
- [ ] Add Example Project

## License

SwiftHTTP is licensed under the Apache v2 License.

## Contact

### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com
