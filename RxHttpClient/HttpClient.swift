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
	func createUrlRequest(url: NSURL) -> NSMutableURLRequestType
	/**
	Creates NSMutableURLRequest with provided NSURL and HTTP Headers
	- parameter url: Url for request
	- parameter headers: Additional HTTP Headers
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable for request
	*/
	func loadData(request: NSURLRequestType) -> Observable<HttpRequestResult>
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable for request
	*/
	func loadStreamData(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents>
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType
	/**
	Creates StreamDataTask
	- parameter taskUid: String, that may be used as unique identifier of the task
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(taskUid: String, request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType
}

public final class HttpClient {
	internal let httpUtilities: HttpUtilitiesType
	internal let serialScheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	internal let concurrentScheduler = ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	internal let sessionConfiguration: NSURLSessionConfiguration
	internal let shouldInvalidateSession: Bool
	
	internal lazy var urlSession: NSURLSessionType = {
		return self.httpUtilities.createUrlSession(self.sessionConfiguration, delegate: self.sessionObserver  as? NSURLSessionDataDelegate, queue: nil)
	}()
	
	internal lazy var sessionObserver: NSURLSessionDataEventsObserverType = {
		return self.httpUtilities.createUrlSessionStreamObserver()
	}()
	
	internal init(sessionConfiguration: NSURLSessionConfiguration, httpUtilities: HttpUtilitiesType) {
		self.httpUtilities = httpUtilities
		self.sessionConfiguration = sessionConfiguration
		shouldInvalidateSession = true
	}
	
	internal init(urlSession: NSURLSessionType, httpUtilities: HttpUtilitiesType) {
		self.httpUtilities = httpUtilities
		shouldInvalidateSession = false
		self.sessionConfiguration = urlSession.configuration
		self.urlSession = urlSession
	}
	
	internal convenience init(httpUtilities: HttpUtilitiesType) {
		self.init(sessionConfiguration: NSURLSessionConfiguration.defaultSessionConfiguration(), httpUtilities: httpUtilities)
	}
	
	/**
	Creates an instance of HttpClient
	- parameter urlSession: NSURLSession that will be used for requests
	*/
	public convenience init(urlSession: NSURLSessionType) {
		self.init(urlSession: urlSession, httpUtilities: HttpUtilities())
	}
	
	/**
	Creates an instance of HttpClient
	- parameter sessionConfiguration: NSURLSessionConfiguration that will be used to create NSURLSession 
	(this session will be canceled while deiniting of HttpClient)
	*/
	public convenience init(sessionConfiguration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()) {
		self.init(sessionConfiguration: sessionConfiguration, httpUtilities: HttpUtilities())
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
	public func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType {
		return httpUtilities.createUrlRequest(url, headers: headers)
	}
	
	/**
	Creates NSMutableURLRequest with provided NSURL
	- parameter url: Url for request
	- returns: Created mutable url request
	*/
	public func createUrlRequest(url: NSURL) -> NSMutableURLRequestType {
		return createUrlRequest(url, headers: nil)
	}
	
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable for request
	*/
	public func loadData(request: NSURLRequestType)	-> Observable<HttpRequestResult> {
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
	public func loadStreamData(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents> {
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
			}
		}
	}
	
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	public func createStreamDataTask(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return createStreamDataTask(NSUUID().UUIDString, request: request, cacheProvider: cacheProvider)
	}

	/**
	Creates StreamDataTask
	- parameter taskUid: String, that may be used as unique identifier of the task
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	public func createStreamDataTask(taskUid: String, request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		let dataTask = urlSession.dataTaskWithRequest(request)
		return httpUtilities.createStreamDataTask(taskUid,
		                                          dataTask: dataTask,
		                                          httpClient: self,
		                                          sessionEvents: sessionObserver.sessionEvents,
		                                          cacheProvider: cacheProvider)
	}
}