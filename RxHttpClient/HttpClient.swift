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
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable that emits HTTP request result events
	*/
	func loadData(request: NSURLRequest) -> Observable<HttpRequestResult>
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable that emits stream events
	*/
	func loadStreamData(request: NSURLRequest, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents>
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
	internal let sessionObserver = NSURLSessionDataEventsObserver()
	internal let urlSession: NSURLSessionType
	
	/**
	Creates an instance of HttpClient
	- parameter sessionConfiguration: NSURLSessionConfiguration that will be used to create NSURLSession
	(this session will be canceled while deiniting of HttpClient)
	*/
	public init(sessionConfiguration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()) {
		urlSession = NSURLSession(configuration: sessionConfiguration,
		             delegate: self.sessionObserver,
		             delegateQueue: nil)
	}
	
	/// Initializer for unit tests only
	internal init(session urlSession: NSURLSessionType) {
		self.urlSession = urlSession
	}
	
	deinit {
		urlSession.invalidateAndCancel()
	}
}

extension HttpClient : HttpClientType {
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable that emits HTTP request result events
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
	- returns: Created observable that emits stream events
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