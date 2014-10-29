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

## Examples

### GET

The most basic request. By default an NSData object will be returned for the response.
```swift
var request = HTTPTask()
request.GET("http://vluxe.io", parameters: nil, success: {(response: HTTPResponse) in
    	if response.responseObject != nil {
            let data = response.responseObject as NSData
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
let fileUrl = NSURL.fileURLWithPath("/Users/dalton/Desktop/file")
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
request.download("http://vluxe.io/assets/images/logo.png", parameters: nil, progress: {(complete: Double) in
    println("percent complete: \(complete)")
    }, success: {(response: HTTPResponse) in
    println("download finished!")
    if response.responseObject != nil {
        //we MUST copy the file from its temp location to a permanent location.
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let newPath = NSURL(string:  "\(paths[0])/\(response.suggestedFilename!)")
        let fileManager = NSFileManager.defaultManager()
        fileManager.removeItemAtURL(newPath, error: nil)
        fileManager.moveItemAtURL(response.responseObject! as NSURL, toURL: newPath, error: nil)
    }

    } ,failure: {(error: NSError, response: HTTPResponse?) in
        println("failure")
})
```

### Upload

```swift
//Dalton, add the background upload example
//still working on finishing it
```

### Authentication

SwiftHTTP supports authentication through [NSURLCredential](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCredential_Class/Reference/Reference.html). Currently only Basic Auth and Digest Auth have been tested.

```swift
var request = HTTPTask()
var auth = HTTPAuth(username: "user", password: "passwd")
auth.persistence = .Permanent
request.auth = auth
request.GET("http://httpbin.org/basic-auth/user/passwd", parameters: nil, success: {(response: HTTPResponse) in
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
    if response.responseObject != nil {
        let data = response.responseObject as NSData
        let str = NSString(data: data, encoding: NSUTF8StringEncoding)
        println("response: \(str)") //prints the HTML of the page
    }
    },failure: {(error: NSError, response: HTTPResponse?) in
        println("error: \(error)")
})
if opt != nil {
    operationQueue.addOperation(opt!)
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
    	if response.responseObject != nil {
            let dict = response.responseObject as Dictionary<String,AnyObject>
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
    if (response.responseObject != nil) {
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

SwiftHTTP requires at least iOS 8/OSX 10.10 or above.

## Installation

Add the `SwiftHTTP.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `SwiftHTTP.framework` to your "Link Binary with Libraries" phase.

## TODOs

- [ ] Complete Docs
- [ ] Add Unit Tests
- [ ] Add Example Project
- [ ] Add [Rouge](https://github.com/acmacalister/Rouge) Installation Docs

## License

SwiftHTTP is licensed under the Apache v2 License.

## Contact

### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com
