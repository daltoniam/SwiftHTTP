SwiftHTTP
=========

Thin wrapper around NSURLSession in swift. Simplifies HTTP requests.

##Example 

## GET

The most basic request. By default an NSData object will be returned for the response.
```swift
var request = HTTPTask()
request.GET("http://vluxe.io", parameters: nil, success: {(response: AnyObject?) -> Void in
    	if response {
            let data = response as NSData
            let str = NSString(data: data, encoding: NSUTF8StringEncoding)
            println("response: \(str)") //prints the HTML of the page
        }
    },failure: {(error: NSError) -> Void in
    	println("error: \(error)")
    })
```

We can also add parameters as with standard container objects.

```swift
var request = HTTPTask()
request.GET("http://google.com", parameters: ["param": "param1", "array": ["first array element","second","third"], "num": 23], success: {(response: AnyObject?) -> Void in
    println("response: \(response)")
    },failure: {(error: NSError) -> Void in
        println("error: \(error)")
    })
```

## POST
A POST request is just as easy as a GET.

```swift
var request = HTTPTask()
request.POST("http://domain.com/create", parameters: ["param": "hi", "something": "else", "key": "value"], success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

## PUT

PUT works the same as post. The example also include a file upload to do a multi form request.

```swift
let fileUrl = NSURL.fileURLWithPath("/Users/dalton/Desktop/file")
var request = HTTPTask()
request.PUT("http://domain.com/1", parameters:  ["param": "hi", "something": "else", "key": "value","file": HTTPUpload(fileUrl: fileUrl)], success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

The HTTPUpload object is use to represent files on disk or in memory file as data.

## DELETE

DELETE works the same as the GET.
```swift
var request = HTTPTask()
request.DELETE("http://domain.com/1", parameters: nil, success: {(response: AnyObject?) -> Void in
    	println("DELETE was successful!")
    },failure: {(error: NSError) -> Void in
    	 println("print the error: \(error)")
    })
```

## HEAD

HEAD works the same as the GET.
```swift
var request = HTTPTask()
request.HEAD("http://domain.com/image.png", parameters: nil, success: {(response: AnyObject?) -> Void in
    	println("The file does exist!")
    },failure: {(error: NSError) -> Void in
		println("File not found: \(error)")
    })
```

## Download

```swift
//Dalton, add the background download example.
//still working on finishing it
```

## Upload

```swift
//Dalton, add the background upload example
//still working on finishing it
```

## BaseURL

SwiftHTTP also supports use a request object with a baseURL. This is super handy for RESTFul API interaction.

```swift
var request = HTTPTask()
request.baseURL = "http://api.someserver.com/1"
request.GET("/users", parameters: ["key": "value"], success: {(response: AnyObject?) -> Void in
    println("Got data from http://api.someserver.com/1/users")
    },failure: {(error: NSError) -> Void in
        println("print the error: \(error)")
    })

request.POST("/users", parameters: ["key": "updatedVale"], success: {(response: AnyObject?) -> Void in
    println("Got data from http://api.someserver.com/1/users")
    },failure: {(error: NSError) -> Void in
        println("print the error: \(error)")
    })

request.GET("/resources", parameters: ["key": "value"], success: {(response: AnyObject?) -> Void in
    println("Got data from http://api.someserver.com/1/resources")
    },failure: {(error: NSError) -> Void in
        println("print the error: \(error)")
    })
```

## Serializers

Request parameters and request responses can also be serialized as needed. By default request are serialized using standard HTTP form encoding. A JSON request and response serializer are provided as well. It is also very simple to create custom serializer by subclass a request or response serializer

```swift
var request = HTTPTask()
//The parameters will be encoding as JSON data and sent.
request.requestSerializer = JSONRequestSerializer()
//The expected response will be JSON and be converted to an object return by NSJSONSerialization instead of a NSData.
request.responseSerializer = JSONResponseSerializer()
request.GET("http://vluxe.io", parameters: nil, success: {(response: AnyObject?) -> Void in
    	if response {
            let dict = response as Dictionary
			println("example of the JSON key: \(dict["key"])")
			println("print the whole response: \(response)")
        }
    },failure: {(error: NSError) -> Void in
    	println("error: \(error)")
    })
```

## Requirements

SwiftHTTP requires at least iOS 7/OSX 10.9 or above.


### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com