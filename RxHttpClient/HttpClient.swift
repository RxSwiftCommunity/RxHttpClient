import Foundation
import RxSwift

public final class HttpClient {
	/// Scheduler for observing data task events
	internal let dataTaskScheduler =
		SerialDispatchQueueScheduler(globalConcurrentQueueQOS: .Utility, internalSerialQueueName: "com.RxHttpClient.HttpClient.DataTask")
	/// Default concurrent scheduler for observing observable sequence created by loadStreamData method
	internal let streamDataObservingScheduler =
		SerialDispatchQueueScheduler(globalConcurrentQueueQOS: .Utility, internalSerialQueueName: "com.RxHttpClient.HttpClient.Stream")
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
			
			let disposable = task.taskProgress.observeOn(object.dataTaskScheduler).subscribe(observer)
			
			task.resume()
			
			return AnonymousDisposable {
				task.cancel()
				disposable.dispose()
			}
			}.observeOn(streamDataObservingScheduler)
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