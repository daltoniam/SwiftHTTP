SwiftHTTP
=========

Thin wrapper around NSURLSession in swift. Simplifies HTTP requests.

##Example 

## GET

```swift
var request = HTTPTask()
request.GET("http://vluxe.io", parameters: nil, success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

## POST

```swift
var request = HTTPTask()
request.POST("http://domain.com/create", parameters: nil, success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

## PUT

```swift
var request = HTTPTask()
request.PUT("http://domain.com/1", parameters: nil, success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

## DELETE

```swift
var request = HTTPTask()
request.DELETE("http://domain.com/1", parameters: nil, success: {(response: AnyObject?) -> Void in
    
    },failure: {(error: NSError) -> Void in
    
    })
```

## HEAD

```swift
var request = HTTPTask()
request.DELETE("http://domain.com/image.png", parameters: nil, success: {(response: AnyObject?) -> Void in
    	println("DELETE was successful!")
    },failure: {(error: NSError) -> Void in
		println("print the error: \(error)")
    })
```

## Download

//Dalton, add the background download example

## Upload

//Dalton, add the background upload example

## Requirements

SwiftHTTP requires at least iOS 7/OSX 10.9 or above.


### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com