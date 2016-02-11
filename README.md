SwiftHTTP
=========

SwiftHTTP is a thin wrapper around NSURLSession in Swift to simplify HTTP requests.

## Features

- Convenient Closure APIs
- NSOperationQueue Support
- Parameter Encoding
- Builtin JSON Request Serialization
- Upload/Download with Progress Closure
- Concise Codebase.


First thing is to import the framework. See the Installation instructions on how to add the framework to your project.

```swift
import SwiftHTTP
```

## Examples

### GET

The most basic request. By default an NSData object will be returned for the response.
```swift
do {
    let opt = try HTTP.GET("https://google.com")
    opt.start { response in
    	if let err = response.error {
			print("error: \(err.localizedDescription)")
			return //also notify app of failure as needed
		}
        print("opt finished: \(response.description)")
        //print("data is: \(response.data)") access the response of the data with response.data
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

We can also add parameters as with standard container objects and they will be properly serialized to their respective HTTP equivalent.

```swift
do {
	//the url sent will be https://google.com?hello=world&param2=value2
    let opt = try HTTP.GET("https://google.com", parameters: ["hello": "world", "param2": "value2"])
    opt.start { response in
    	if let err = response.error {
			print("error: \(err.localizedDescription)")
			return //also notify app of failure as needed
		}
        print("opt finished: \(response.description)")
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

The `HTTPResponse` contains all the common HTTP response data, such as the responseObject of the data and the headers of the response.

### HTTP Methods

All the common HTTP methods are avalaible as convenience methods as well.

### POST

```swift
let params = ["param": "param1", "array": ["first array element","second","third"], "num": 23, "dict": ["someKey": "someVal"]]
do {
    let opt = try HTTP.POST("https://domain.com/new", parameters: params)
    opt.start { response in
    //do things...
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

### PUT

```swift
let opt = try HTTP.PUT("https://domain.com/1")
```

### HEAD

```swift
let opt = try HTTP.HEAD("https://domain.com/1")
```

### DELETE

```swift
let opt = try HTTP.DELETE("https://domain.com/1")
```

### Background Downloads

```
//TODO implement background download...
```

### Upload

File uploads can be done using the `Upload` object. All files to upload should be wrapped in a Upload object and added as a parameter.

```swift
let fileUrl = NSURL(fileURLWithPath: "/Users/dalton/Desktop/testfile")!
do {
    let opt = try HTTP.POST("https://domain.com/new", parameters: ["aParam": "aValue", "file": Upload(fileUrl: fileUrl)])
    opt.start { response in
    //do things...
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```
`Upload` comes in both a on disk fileUrl version and a NSData version.

### Custom Headers

Custom HTTP headers can be add to a request with the standard NSMutableRequest API:

```swift
do {
    let opt = try HTTP.GET("https://domain.com", parameters: ["hello": "there"], headers: ["header": "value"])
    opt.start { response in
        //do stuff
    }
} catch let error {
    print("couldn't serialize the paraemeters: \(error)")
}
```

### SSL Pinning

SSL Pinning is also supported in SwiftHTTP. 

```swift
do {
    let opt = try HTTP.GET("https://domain.com")
    opt.security = HTTPSecurity(certs: [HTTPSSLCert(data: data)], usePublicKeys: true)
	//opt.security = HTTPSecurity() //uses the .cer files in your app's bundle
    opt.start { response in
    	if let err = response.error {
			print("error: \(err.localizedDescription)")
			return //also notify app of failure as needed
		}
        print("opt finished: \(response.description)")
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```
You load either a `NSData` blob of your certificate or you can use a `SecKeyRef` if you have a public key you want to use. The `usePublicKeys` bool is whether to use the certificates for validation or the public keys. The public keys will be extracted from the certificates automatically if `usePublicKeys` is choosen.

### Authentication

SwiftHTTP supports authentication through [NSURLCredential](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLCredential_Class/Reference/Reference.html). Currently only Basic Auth and Digest Auth have been tested.

```swift
do {
    let opt = try HTTP.GET("https://domain.com")
    //the auth closures will continually be called until a successful auth or rejection
	var attempted = false
	opt.auth = { challenge in
	    if !attempted {
	        attempted = true
	        return NSURLCredential(user: "user", password: "passwd", persistence: .ForSession)
	    }
	    return nil //auth failed, nil causes the request to be properly cancelled.
	}
    opt.start { response in
    //do stuff
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

Allow all certificates example:

```swift
do {
    let opt = try HTTP.GET("https://domain.com")
    //the auth closures will continually be called until a successful auth or rejection
	var attempted = false
	opt.auth = { challenge in
    if !attempted {
        attempted = true
        return NSURLCredential(forTrust: challenge.protectionSpace.serverTrust)
    }
    return nil
}
    opt.start { response in
    //do stuff
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

### Operation Queue

Operation queues are also supported in SwiftHTTP.

```swift
let operationQueue = NSOperationQueue()
operationQueue.maxConcurrentOperationCount = 2
do {
    let opt = try HTTP.New("https://google.com", method: .GET)
    opt.onFinish = { response in
    //do stuff
    }
    operationQueue.addOperation(opt)
} catch let error {
    print("got an error creating the request: \(error)")
}
```

### Cancel

Let's say you want to cancel the request a little later, call the `cancel` method that we get from it being an NSOperation subclass.

```swift
opt.cancel()
```

### JSON Request Serializer

Request parameters can also be serialized to JSON as needed. By default request are serialized using standard HTTP form encoding.

```swift
do {
    let opt = try HTTP.New("https://google.com", method: .GET, requestSerializer: JSONParameterSerializer())
    opt.onFinish = { response in
    	if let err = response.error {
			print("error: \(err.localizedDescription)")
			return //also notify app of failure as needed
		}
        print("opt finished: \(response.description)")
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```

### Progress

SwiftHTTP can monitor the progress of a request.

```swift
do {
    let opt = try HTTP.GET("https://domain.com/somefile")
    opt.progress = { progress in
        print("progress: \(progress)") //this will be between 0 and 1.
    }
    opt.start { response in
    //do stuff
    }
} catch let error {
    print("got an error creating the request: \(error)")
}
```


### Global handlers

SwiftHTTP also has global handlers, to reduce the requirement of repeat HTTP modifiers, such as a auth header or setting `NSMutableURLRequest` properties such as `timeoutInterval`. 

```swift
//modify NSMutableURLRequest for any Factory method call (e.g. HTTP.GET, HTTP.POST, HTTP.New, etc).
HTTP.globalRequest { req in
    req.timeoutInterval = 5
}

//set a global SSL pinning setting
HTTP.globalSecurity(HTTPSecurity()) //see the SSL section for more info

//set global auth handler. See the Auth section for more info
HTTP.globalAuth { challenge in
    return NSURLCredential(user: "user", password: "passwd", persistence: .ForSession)
}
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
struct Response: JSONJoy {
    let status: String?
    init(_ decoder: JSONDecoder) {
        status = decoder["status"].string
    }
}

do {
    let opt = try HTTP.GET("http://localhost:8080/bar")
    opt.start { response in
        if let error = response.error {
            print("got an error: \(error)")
            return
        }
        let resp = Response(JSONDecoder(response.data))
        if let status = resp.status {
            print("completed: \(status)")
        }
    }
} catch let error {
    print("got an error: \(error)")
}
```

## POST example

```go
package main

import (
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/bar", func(w http.ResponseWriter, r *http.Request) {
        fmt.Println("header: ", r.Header.Get("Content-Type"))
        upload, header, err := r.FormFile("file")
        if err != nil {
            w.Write([]byte("{\"error\": \"bad file upload\"}")) //normally be a 500 status code
            return
        }
        file, err := os.Create(header.Filename) // we would normally need to generate unique filenames.
        if err != nil {
            w.Write([]byte("{\"error\": \"system error occured\"}")) //normally be a 500 status code
            return
        }
        io.Copy(file, upload) // write the uploaded file to disk.
        w.Write([]byte("{\"status\": \"ok\"}")) 
    })

    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Now for the Swift:

```swift
struct Response: JSONJoy {
    let status: String?
    let error: String?
    init(_ decoder: JSONDecoder) {
        status = decoder["status"].string
        error = decoder["error"].string
    }
}

do {
    let url = NSURL(fileURLWithPath: "/Users/dalton/Desktop/dalton.jpeg")
    let opt = try HTTP.POST("http://localhost:8080/bar", parameters: ["test": "value", "file": Upload(fileUrl: url)])
    opt.start { response in
        if let error = response.error {
            print("got an error: \(error)")
            return
        }
        let resp = Response(JSONDecoder(response.data))
        if let err = resp.error {
            print("got an error: \(err)")
        }
        if let status = resp.status {
            print("completed: \(status)")
        }
    }
} catch let error {
    print("got an error: \(error)")
}
```

## JSON Parsing

Swift has a lot of great JSON parsing libraries, but I made one specifically designed for JSON to object serialization.

[JSONJoy-Swift](https://github.com/daltoniam/JSONJoy-Swift)

## Requirements

SwiftHTTP works with iOS 7/OSX 10.10 or above. It is recommended to use iOS 8/10.10 or above for Cocoapods/framework support.
To use SwiftHTTP with a project targeting iOS 7, you must include all Swift files directly in your project.

## Installation

### CocoaPods

Check out [Get Started](https://guides.cocoapods.org/using/getting-started.html) tab on [cocoapods.org](http://cocoapods.org/).

To use SwiftHTTP in your project add the following 'Podfile' to your project

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '8.0'
	use_frameworks!

	pod 'SwiftHTTP', '~> 1.0.4'

Then run:

    pod install

### Carthage

Check out the [Carthage](https://github.com/Carthage/Carthage) docs on how to add a install. The `SwiftHTTP` framework is already setup with shared schemes.

[Carthage Install](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate SwiftHTTP into your Xcode project using Carthage, specify it in your `Cartfile`:

```
github "daltoniam/SwiftHTTP" >= 1.0.4
```

### Rogue

First see the [installation docs](https://github.com/acmacalister/Rogue) for how to install Rogue.

To install SwiftHTTP run the command below in the directory you created the rogue file.

```
rogue add https://github.com/daltoniam/SwiftHTTP
```

Next open the `libs` folder and add the `SwiftHTTP.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `SwiftHTTP.framework` to your "Link Binary with Libraries" phase. Make sure to add the `libs` folder to your `.gitignore` file.

### Other

Simply grab the framework (either via git submodule or another package manager).

Add the `SwiftHTTP.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `SwiftHTTP.framework` to your "Link Binary with Libraries" phase.

### Add Copy Frameworks Phase

If you are running this in an OSX app or on a physical iOS device you will need to make sure you add the `SwiftHTTP.framework` included in your app bundle. To do this, in Xcode, navigate to the target configuration window by clicking on the blue project icon, and selecting the application target under the "Targets" heading in the sidebar. In the tab bar at the top of that window, open the "Build Phases" panel. Expand the "Link Binary with Libraries" group, and add `SwiftHTTP.framework`. Click on the + button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `SwiftHTTP.framework`.

## TODOs

- [ ] Linux support?
- [ ] Add more unit tests

## License

SwiftHTTP is licensed under the Apache v2 License.

## Contact

### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com
