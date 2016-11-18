RxHttpClient
----
[![Build Status](https://travis-ci.org/reloni/RxHttpClient.svg?branch=master)](https://travis-ci.org/reloni/RxHttpClient)
[![codecov](https://codecov.io/gh/reloni/RxHttpClient/branch/master/graph/badge.svg)](https://codecov.io/gh/reloni/RxHttpClient)
![Platform iOS](https://img.shields.io/badge/platform-iOS-lightgray.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

RxHttpClient is a "reactive wrapper" around NSURLSession. Under the hood it implements session delegates (like NSURLSessionDelegate or NSURLSessionTaskDelegate) and translates session events into Observables using [RxSwift](https://github.com/ReactiveX/RxSwift). Main purpose of this framework is to make "streaming" data as simple as possible and provide convenient features for caching data.

##Requirements
- Xcode 8.1
- Swift 3.0.1

##Installation
Now only [Carthage](https://github.com/Carthage/Carthage) supported:
```
github "ReactiveX/RxSwift" ~> 3.0
github "Reloni/RxHttpClient"
```
RxHttpClient uses RxSwift so it should be included into cartfile.

```
carthage update RxSwift
carthage update RxHttpClient
```
Commands above are necessary if Carthage trying to build RxHttpClient before RxSwift.

##Usage
####StreamData
For create request and streaming data:
```
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
```
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
client.request(url: url, cacheProvider: MemoryCacheProvider()).subscribe(onNext: { event in
  guard case StreamTaskEvents.success(let cacheProvider) = event else { return }

  if let cacheProvider = cacheProvider {
    // getting cached data from provider
    let downloadedData = cacheProvider.getData()
  }
}).addDisposableTo(bag)
```

####Convenience methods
It's also possible to simply invoke request and receive data using loadData method (in this case errors are forwarded with RxSwift error mechanism):
```
let client = HttpClient()
let bag = DisposeBag()
let url = URL(string: "url_to_resource")!
client.requestData(url: url).subscribe(onNext: { data in /* do something with returned data */ }, onError: { error in
  switch error {
  case HttpClientError.clientSideError(let error): break /* Client-side error */
  case let HttpClientError.invalidResponse(response, data): break /* Occurs when server did't return success HTTP code (not in 2xx) */
  default: break
  }
}).addDisposableTo(bag)
```

JSON deserialized object may be requested in same way:

```
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

####StreamDataTask
StreamDataTask is a more "low level" object that wraps NSURLSessionDataTask. In most situations is't more convenient to use loadStreamData method (it actually simply forwards events from StreamDataTask), but if necessary StreamDataTask may be used in this way:
```
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

##How it works
HttpClient object holds it's own NSURLSession. It creates session by providing a session delegate object for handling session-related events. So StreamTaskEvents enum actually represents this session events, for example `case receiveResponse(URLResponse)` means that `URLSession(_:dataTask:didReceiveResponse:completionHandler:)` delegate method was invoked.
Because NSURLSession holds strong reference to delegate it should be invalidated, HttpClient do that in deinitializer by invoking finishTasksAndInvalidate() method, so session will allow running tasks to finish work.

## Contributing
For contributing please check out **develop** branch and also target it in pull request.
