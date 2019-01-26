import Foundation
import RxSwift

public final class HttpClient {
	/// Scheduler for observing data task events
	internal let dataTaskScheduler = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "com.RxHttpClient.HttpClient.DataTask")
	/// Default concurrent scheduler for observing observable sequence created by loadStreamData method
	internal let streamDataObservingScheduler = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "com.RxHttpClient.HttpClient.Stream")
    internal let sessionObserver: NSURLSessionDataEventsObserverType
	internal let urlSession: URLSessionType
	
	public let urlRequestCacheProvider: UrlRequestCacheProviderType?
	
	public let requestPlugin: RequestPluginType?
	
	/**
	Creates an instance of HttpClient
	- parameter sessionConfiguration: NSURLSessionConfiguration that will be used to create NSURLSession
	(this session will be canceled while deiniting of HttpClient)
	- parameter urlRequestCacheProvider: Cache provider that will be used for caching requests
	*/
	public init(sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
	            urlRequestCacheProvider: UrlRequestCacheProviderType? = nil,
	            requestPlugin: RequestPluginType? = nil,
                sessionDelegate: NSURLSessionDataEventsObserverType = NSURLSessionDataEventsObserver()) {
        
        self.sessionObserver = sessionDelegate
		urlSession = URLSession(configuration: sessionConfiguration,
		                          delegate: self.sessionObserver,
		                          delegateQueue: nil)
		self.urlRequestCacheProvider = urlRequestCacheProvider
        self.requestPlugin = requestPlugin
	}
	
	/// Initializer for unit tests only
	internal init(session urlSession: URLSessionType,
	              urlRequestCacheProvider: UrlRequestCacheProviderType? = nil,
	              requestPlugin: RequestPluginType? = nil,
                  sessionDelegate: NSURLSessionDataEventsObserverType = NSURLSessionDataEventsObserver()) {
		self.urlSession = urlSession
		self.urlRequestCacheProvider = urlRequestCacheProvider
        self.requestPlugin = requestPlugin
        self.sessionObserver = sessionDelegate
	}
	
	deinit {
		urlSession.finishTasksAndInvalidate()
	}
}

extension HttpClient : HttpClientType {
	public func request(_ request: URLRequest, dataCacheProvider: DataCacheProviderType? = nil) -> Observable<StreamTaskEvents> {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return Disposables.create() }
			
			// clears cache provider before start
			dataCacheProvider?.clearData()
			
			let useRequest = object.requestPlugin?.prepare(request: request) ?? request
            
			let task = object.createStreamDataTask(request: useRequest, dataCacheProvider: dataCacheProvider)
			
			let disposable = task.taskProgress.observeOn(object.dataTaskScheduler).subscribe(observer)
            
			task.resume()
			
			return Disposables.create {
				task.cancel()
				disposable.dispose()
			}
			}.subscribeOn(dataTaskScheduler).observeOn(streamDataObservingScheduler)
	}
	
	public func createStreamDataTask(taskUid: String, request: URLRequest, dataCacheProvider: DataCacheProviderType?) -> StreamDataTaskType {
		let dataTask = urlSession.dataTaskWithRequest(request)
        return StreamDataTask(taskUid: taskUid,
                              dataTask: dataTask, 
                              sessionEvents: sessionObserver.sessionEvents, 
                              dataCacheProvider: dataCacheProvider, 
                              requestPlugin: requestPlugin)
	}
}
