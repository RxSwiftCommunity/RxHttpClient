import Foundation
@testable import RxHttpClient
import RxSwift

public class FakeRequest : NSMutableURLRequestType {
	public var HTTPMethod: String? = "GET"
	var headers = [String: String]()
	public var URL: NSURL?
	public var allHTTPHeaderFields: [String: String]? {
		return headers
	}
	
	public init(url: NSURL? = nil) {
		self.URL = url
	}
	
	public func addValue(value: String, forHTTPHeaderField: String) {
		headers[forHTTPHeaderField] = value
	}
	
	public func setHttpMethod(method: String) {
		HTTPMethod = method
	}
}

public class FakeResponse : NSURLResponseType, NSHTTPURLResponseType {
	public var expectedContentLength: Int64
	public var MIMEType: String?
	
	public init(contentLenght: Int64) {
		expectedContentLength = contentLenght
	}
}

public enum FakeDataTaskMethods {
	case resume(FakeDataTask)
	case suspend(FakeDataTask)
	case cancel(FakeDataTask)
}

public class FakeDataTask : NSURLSessionDataTaskType {
	@available(*, unavailable, message="completion unavailiable. Use FakeSession.sendData instead (session observer will used to send data)")
	var completion: DataTaskResult?
	let taskProgress = PublishSubject<FakeDataTaskMethods>()
	var originalRequest: NSMutableURLRequestType?
	var isCancelled = false
	var resumeInvokeCount = 0
	
	public init(completion: DataTaskResult?) {
		//self.completion = completion
	}
	
	public func resume() {
		resumeInvokeCount += 1
		taskProgress.onNext(.resume(self))
	}
	
	public func suspend() {
		taskProgress.onNext(.suspend(self))
	}
	
	public func cancel() {
		if !isCancelled {
			taskProgress.onNext(.cancel(self))
			isCancelled = true
		}
	}
	
	public func getOriginalMutableUrlRequest() -> NSMutableURLRequestType? {
		return originalRequest
	}
}

public class FakeSession : NSURLSessionType {
	var task: FakeDataTask?
	var isInvalidatedAndCanceled = false
	
	public var configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
	
	public init(fakeTask: FakeDataTask? = nil) {
		task = fakeTask
	}
	
	/// Send data as stream (this data should be received through session delegate)
	func sendData(task: NSURLSessionDataTaskType, data: NSData?, streamObserver: NSURLSessionDataEventsObserver) {
		if let data = data {
			streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self, dataTask: task, data: data))
		}
		// simulate delay
		NSThread.sleepForTimeInterval(0.01)
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: nil))
	}
	
	func sendError(task: NSURLSessionDataTaskType, error: NSError, streamObserver: NSURLSessionDataEventsObserver) {
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: error))
	}
	
	public func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		guard let task = self.task else {
			return FakeDataTask(completion: completionHandler)
		}
		//task.completion = completionHandler
		return task
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestType, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		fatalError("should not invoke dataTaskWithRequest with completion handler")
		guard let task = self.task else {
			return FakeDataTask(completion: completionHandler)
		}
		//task.completion = completionHandler
		task.originalRequest = request
		return task
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestType) -> NSURLSessionDataTaskType {
		guard let task = self.task else {
			return FakeDataTask(completion: nil)
		}
		task.originalRequest = request
		return task
	}
	
	public func invalidateAndCancel() {
		// set flag that session was invalidated and canceled
		isInvalidatedAndCanceled = true
		
		// invoke cancelation of task
		task?.cancel()
	}
}

public class FakeHttpUtilities : HttpUtilitiesType {
	//var fakeObserver: UrlSessionStreamObserverType?
	var streamObserver: NSURLSessionDataEventsObserverType?
	var fakeSession: NSURLSessionType?
	
	public func createUrlRequest(baseUrl: String, parameters: [String : String]?) -> NSMutableURLRequestType? {
		return FakeRequest(url: NSURL(baseUrl: baseUrl, parameters: parameters))
	}
	
	public func createUrlRequest(baseUrl: String, parameters: [String : String]?, headers: [String : String]?) -> NSMutableURLRequestType? {
		let req = createUrlRequest(baseUrl, parameters: parameters)
		headers?.forEach { req?.addValue($1, forHTTPHeaderField: $0) }
		return req
	}
	
	public func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType {
		let req = FakeRequest(url: url)
		headers?.forEach { req.addValue($1, forHTTPHeaderField: $0) }
		return req
	}
	
	public func createUrlSession(configuration: NSURLSessionConfiguration, delegate: NSURLSessionDelegate?, queue: NSOperationQueue?) -> NSURLSessionType {
		guard let session = fakeSession else {
			return FakeSession()
		}
		return session
	}
	
	func createUrlSessionStreamObserver() -> NSURLSessionDataEventsObserverType {
		//		guard let observer = fakeObserver else {
		//			return FakeUrlSessionStreamObserver()
		//		}
		//		return observer
		guard let observer = streamObserver else {
			return NSURLSessionDataEventsObserver()
		}
		return observer
	}
	
	public func createStreamDataTask(taskUid: String, request: NSMutableURLRequestType, sessionConfiguration: NSURLSessionConfiguration, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return StreamDataTask(taskUid: NSUUID().UUIDString, request: request, httpUtilities: self, sessionConfiguration: sessionConfiguration, cacheProvider: cacheProvider)
		//return FakeStreamDataTask(request: request, observer: createUrlSessionStreamObserver(), httpUtilities: self)
	}
}