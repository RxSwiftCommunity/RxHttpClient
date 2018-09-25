RxHttpClient
----
[![Build Status](https://travis-ci.org/RxSwiftCommunity/RxHttpClient.svg?branch=master)](https://travis-ci.org/RxSwiftCommunity/RxHttpClient)
[![codecov](https://codecov.io/gh/RxSwiftCommunity/RxHttpClient/branch/master/graph/badge.svg)](https://codecov.io/gh/RxSwiftCommunity/RxHttpClient)
![Platform iOS](https://img.shields.io/badge/platform-iOS-lightgray.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codebeat badge](https://codebeat.co/badges/be008a71-5755-48fa-a861-8ce0d880ee14)](https://codebeat.co/projects/github-com-rxswiftcommunity-rxhttpclient-master)

RxHttpClient is a "reactive wrapper" around NSURLSession. Under the hood it implements session delegates (like NSURLSessionDelegate or NSURLSessionTaskDelegate) and translates session events into Observables using [RxSwift](https://github.com/ReactiveX/RxSwift). Main purpose of this framework is to make "streaming" data as simple as possible and provide convenient features for caching data.

## Requirements
- Xcode 10.0
- Swift 4.2

## Installation
Now only [Carthage](https://github.com/Carthage/Carthage) supported:
```
github "ReactiveX/RxSwift" ~> 4.0
github "RxSwiftCommunity/RxHttpClient"
```
RxHttpClient uses RxSwift so it should be included into cartfile.

```
carthage update RxSwift
carthage update RxHttpClient
```
Commands above are necessary if Carthage trying to build RxHttpClient before RxSwift.

## Usage
#### StreamData
For create request and streaming data:
```swift
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
client.request(url: url).subscribe (onNext: { event in
  switch event {
  case StreamTaskEvents.receiveResponse(let response): break /* Occurs after receiving response from remote server */
  case StreamTaskEvents.receiveData(let data): break /* Occurs after receiving chunk of data from server (generally occurred many times) */
  case StreamTaskEvents.error(let error): break /* Occurs in case of client-side error */
  case StreamTaskEvents.success: break /* Occurs after successful completion of request */
  default: break
  }
}).addDisposableTo(bag)
```

If dealing with every chunk of data is not necessary it's possible to pass an instance of cache provider and in success event grab all data from that provider (for now there is only MemoryCacheProvider object):
```swift
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
client.request(url: url, dataCacheProvider: MemoryCacheProvider()).subscribe(onNext: { event in
  guard case StreamTaskEvents.success(let dataCacheProvider) = event else { return }

  if let dataCacheProvider = dataCacheProvider {
    // getting cached data from provider
    let downloadedData = dataCacheProvider.getData()
  }
}).addDisposableTo(bag)
```

#### Convenience methods
It's also possible to simply invoke request and receive data using loadData method (in this case errors are forwarded with RxSwift error mechanism):
```swift
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
// by default HTTP GET request will be performed
client.requestData(url: url).subscribe(onNext: { data in /* do something with returned data */ }, onError: { error in
  switch error {
  case HttpClientError.clientSideError(let error): break /* Client-side error */
  case let HttpClientError.invalidResponse(response, data): break /* Occurs when server did't return success HTTP code (not in 2xx) */
  default: break
  }
}).addDisposableTo(bag)

// use HTTP POST and send data
let sendJson = ["Key1":"Value1", "Key2":"Value2"]
let sendJsonData = try! JSONSerialization.data(withJSONObject: sendJson, options: [])
client.requestData(url: url, method: .post, body: sendJsonData).subscribe(onNext: { data in /* do something with returned data */ }).addDisposableTo(bag)

// or simply pass JSON as parameter
let sendJson = ["Key1":"Value1", "Key2":"Value2"]
client.requestData(url: url, method: .put, jsonBody: sendJson, options: [], httpHeaders: ["Header1": "HeaderVal1"]).subscribe(onNext: { _ in expectation.fulfill() }).addDisposableTo(bag)
```

JSON deserialized object may be requested in same way:

```swift
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
client.requestJson(url: url).subscribe(onNext: { json in /* do something with returned data */ }, onError: { error in
  switch error {
  case HttpClientError.clientSideError(let error): break /* Client-side error */
  case let HttpClientError.invalidResponse(response, data): break /* Occurs when server did't return success HTTP code (not in 2xx) */
  default: break
  }
}).addDisposableTo(bag)
```

#### Response caching
HttpClient can cache latest response for GET request. To use caching, HttpClient should be initialized with instance of UrlRequestCacheProviderType:

```swift
// directory where cache data will be saved
let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Cache")
// instance of UrlRequestFileSystemCacheProvider that will store cached data in specified directory
let urlCacheProvider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
let client = HttpClient(urlRequestCacheProvider: urlCacheProvider)

// Use specific cache mode for request
// If data for URL already cached, this data will be returned immediately and after that request to the server will be invoked
client.requestJson(url: url, requestCacheMode: CacheMode(cacheResponse: true, returnCachedResponse: true, invokeRequest: true)).subscribe( /* */).addDisposableTo(bag)

// If returnCachedResponse is false, cached data will not be returned even if exists
client.requestJson(url: url, requestCacheMode: CacheMode(cacheResponse: true, returnCachedResponse: false, invokeRequest: true)).subscribe( /* */).addDisposableTo(bag)

// use predefined mode
// "offline mode", use only cache and don't invoke request to server
client.requestJson(url: url, requestCacheMode: .cacheOnly).subscribe( /* */).addDisposableTo(bag)
```  

#### StreamDataTask
StreamDataTask is a more "low level" object that wraps NSURLSessionDataTask. In most situations is't more convenient to use loadStreamData method (it actually simply forwards events from StreamDataTask), but if necessary StreamDataTask may be used in this way:
```swift
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
//let request = client.createUrlRequest(url, headers: ["Header": "Value"])
let request = URLRequest(url: url, headers: ["Header": "Value"])
let task = client.createStreamDataTask(request: request, cacheProvider: nil)
// represents same events as loadStreamData method
task.taskProgress.subscribe(onNext: { event in
  switch event {
  case StreamTaskEvents.receiveResponse(let response): break /* Occurs after receiving response from remote server */
  case StreamTaskEvents.receiveData(let data): break /* Occurs after receiving chunk of data from server (generally occurred many times) */
  case StreamTaskEvents.error(let error): break /* Occurs in case of client-side error */
  case StreamTaskEvents.success: break /* Occurs after successful completion of request */
  default: break
  }
  }).addDisposableTo(bag)

// resume task
task.resume()
```

#### MIME type conversion
This framework also contains useful methods to convert, for example, MIME type to file extension, or UTI type to MIME type:
```swift
let extension = MimeTypeConverter.utiToFileExtension("public.mp3") // returns "mp3"
let uti = MimeTypeConverter.mimeToUti("audio/mpeg") // returns "public.mp3"

// it also works with strings
let mime = "public.mp3".asUtiType.mimeType // returns "audio/mpeg"
```

## How it works
HttpClient object holds it's own NSURLSession. It creates session by providing a session delegate object for handling session-related events. So StreamTaskEvents enum actually represents this session events, for example `case receiveResponse(URLResponse)` means that `URLSession(_:dataTask:didReceiveResponse:completionHandler:)` delegate method was invoked.
Because NSURLSession holds strong reference to delegate it should be invalidated, HttpClient do that in deinitializer by invoking finishTasksAndInvalidate() method, so session will allow running tasks to finish work.

## License

Copyright (c) 2017 RxSwiftCommunity https://github.com/RxSwiftCommunity

Distributed under The MIT License:

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
