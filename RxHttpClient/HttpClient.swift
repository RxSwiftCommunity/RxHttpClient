import Foundation
import RxSwift

public enum HttpRequestResult {
	case success
	case successData(NSData)
	case error(ErrorType)
}

public protocol HttpClientType {
	func createUrlRequest(url: NSURL) -> NSMutableURLRequestType
	func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType
	func loadData(request: NSURLRequestType) -> Observable<HttpRequestResult>
	func loadStreamData(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> Observable<StreamTaskResult>
	func createStreamDataTask(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType
}

public class HttpClient {
	internal let httpUtilities: HttpUtilitiesType
	internal let scheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
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
	
	public convenience init(urlSession: NSURLSessionType) {
		self.init(urlSession: urlSession, httpUtilities: HttpUtilities())
	}
	
	public convenience init(sessionConfiguration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()) {
		self.init(sessionConfiguration: sessionConfiguration, httpUtilities: HttpUtilities())
	}
	
	deinit {
		guard shouldInvalidateSession else { return }
		urlSession.invalidateAndCancel()
	}
}

extension HttpClient : HttpClientType {
	public func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType {
		return httpUtilities.createUrlRequest(url, headers: headers)
	}
	
	public func createUrlRequest(url: NSURL) -> NSMutableURLRequestType {
		return createUrlRequest(url, headers: nil)
	}
	
	public func loadData(request: NSURLRequestType)	-> Observable<HttpRequestResult> {
		return loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).flatMapLatest { result -> Observable<HttpRequestResult> in		
			switch result {
			case Result.error(let error): return Observable.just(.error(error))
			case Result.success(let box):
				guard case StreamTaskEvents.Success(let cache) = box.value else { return Observable.empty() }
				
				guard let cacheProvider = cache where cacheProvider.currentDataLength > 0 else { return Observable.just(.success) }

				return Observable.just(.successData(cacheProvider.getCurrentData()))
			}
		}.observeOn(scheduler).shareReplay(0)
	}
	
	public func loadStreamData(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> Observable<StreamTaskResult> {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			let task = object.createStreamDataTask(request, cacheProvider: cacheProvider)
			
			let disposable = task.taskProgress.catchError { error in
				observer.onNext(Result.error(error))
				observer.onCompleted()
				return Observable.empty()
			}.bindNext { result in
				if case Result.success(let box) = result {
				}
				observer.onNext(result)
				
				if case Result.success(let box) = result, case .Success = box.value {
					observer.onCompleted()
				}
			}
			
			task.resume()
			
			return AnonymousDisposable {
				task.cancel()
				disposable.dispose()
			}
		}.observeOn(scheduler).shareReplay(0)
	}
	
	public func createStreamDataTask(request: NSURLRequestType, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		let dataTask = urlSession.dataTaskWithRequest(request)
		return httpUtilities.createStreamDataTask(NSUUID().UUIDString,
		                                          dataTask: dataTask,
		                                          httpClient: self,
		                                          sessionEvents: sessionObserver.sessionEvents,
		                                          cacheProvider: cacheProvider)
	}
}