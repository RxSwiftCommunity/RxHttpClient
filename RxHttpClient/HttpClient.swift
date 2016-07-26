import Foundation
import RxSwift

/// Result of HTTP Request
public enum HttpRequestResult {
	/// Request successfuly ended without any data provided
	case success
	/// Request successfuly ended with data
	case successData(NSData)
	/// Request ended with error
	case error(ErrorType)
}

public protocol HttpClientType {
	/**
	Creates NSMutableURLRequest with provided NSURL
	- parameter url: Url for request
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: NSURL) -> NSMutableURLRequest
	/**
	Creates NSMutableURLRequest with provided NSURL and HTTP Headers
	- parameter url: Url for request
	- parameter headers: Additional HTTP Headers
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequest
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable for request
	*/
	func loadData(request: NSURLRequest) -> Observable<HttpRequestResult>
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable for request
	*/
	func loadStreamData(request: NSURLRequest, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents>
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(request: NSURLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType
	/**
	Creates StreamDataTask
	- parameter taskUid: String, that may be used as unique identifier of the task
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(taskUid: String, request: NSURLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType
}

public final class HttpClient {
	internal let serialScheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	internal let concurrentScheduler = ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	internal let sessionConfiguration: NSURLSessionConfiguration
	internal var shouldInvalidateSession: Bool
	internal let sessionObserver = NSURLSessionDataEventsObserver()
	
	internal lazy var urlSession: NSURLSessionType = {
		return NSURLSession(configuration: self.sessionConfiguration,
		                    delegate: self.sessionObserver,
		                    delegateQueue: nil)
	}()
	
	/**
	Creates an instance of HttpClient
	- parameter sessionConfiguration: NSURLSessionConfiguration that will be used to create NSURLSession
	(this session will be canceled while deiniting of HttpClient)
	*/
	public init(sessionConfiguration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()) {
		self.sessionConfiguration = sessionConfiguration
		shouldInvalidateSession = true
	}
	
	/**
	Creates an instance of HttpClient
	- parameter urlSession: NSURLSession that will be used for requests
	*/
	public convenience init(urlSession: NSURLSession) {
		self.init(session: urlSession as NSURLSessionType)
	}
	
	internal init(session urlSession: NSURLSessionType) {
		shouldInvalidateSession = false
		self.sessionConfiguration = urlSession.configuration
		self.urlSession = urlSession
	}
	
	deinit {
		guard shouldInvalidateSession else { return }
		urlSession.invalidateAndCancel()
	}
}

extension HttpClient : HttpClientType {
	/**
	Creates NSMutableURLRequest with provided NSURL and HTTP Headers
	- parameter url: Url for request
	- parameter headers: Additional HTTP Headers
	- returns: Created mutable url request
	*/
	public func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequest {
		let request = NSMutableURLRequest(URL: url)
		headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
		return request
	}
	
	/**
	Creates NSMutableURLRequest with provided NSURL
	- parameter url: Url for request
	- returns: Created mutable url request
	*/
	public func createUrlRequest(url: NSURL) -> NSMutableURLRequest {
		return createUrlRequest(url, headers: nil)
	}
	
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable for request
	*/
	public func loadData(request: NSURLRequest)	-> Observable<HttpRequestResult> {
		return loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).observeOn(concurrentScheduler)
			.flatMapLatest { result -> Observable<HttpRequestResult> in

			if case StreamTaskEvents.error(let error) = result {
				return Observable.just(.error(error))
			}

			guard case StreamTaskEvents.success(let cache) = result else { return Observable.empty() }
				
			guard let cacheProvider = cache where cacheProvider.currentDataLength > 0 else { return Observable.just(.success) }

			return Observable.just(.successData(cacheProvider.getCurrentData()))
			
		}
	}
	
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable for request
	*/
	public func loadStreamData(request: NSURLRequest, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents> {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			// clears cache provider before start
			if let cacheProvider = cacheProvider { cacheProvider.clearData() }
			
			let task = object.createStreamDataTask(request, cacheProvider: cacheProvider)
			
			let disposable = task.taskProgress.observeOn(object.serialScheduler).catchError { error in
				observer.onNext(StreamTaskEvents.error(error))
				observer.onCompleted()
				return Observable.empty()
			}.bindNext { result in
				observer.onNext(result)

				if case .success = result {
					observer.onCompleted()
				}
			}
			
			task.resume()
			
			return AnonymousDisposable {
				task.cancel()
				disposable.dispose()
				observer.onCompleted()
			}
		}
	}
	
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	public func createStreamDataTask(request: NSURLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return createStreamDataTask(NSUUID().UUIDString, request: request, cacheProvider: cacheProvider)
	}

	/**
	Creates StreamDataTask
	- parameter taskUid: String, that may be used as unique identifier of the task
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	public func createStreamDataTask(taskUid: String, request: NSURLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		let dataTask = urlSession.dataTaskWithRequest(request)
		return StreamDataTask(taskUid: taskUid, dataTask: dataTask, httpClient: self, sessionEvents: sessionObserver.sessionEvents, cacheProvider: cacheProvider)
	}
}