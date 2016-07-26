import Foundation
import RxSwift
import RxCocoa

public protocol StreamTaskType {
	/// Identifier of a task
	var uid: String { get }
	/// Resumes task
	func resume()
	//func suspend()
	/// Cancels task
	func cancel()
	/// Is task resumed
	var resumed: Bool { get }
}

public enum StreamTaskEvents {
	/// This event will be sended after receiving (and cacnhing) new chunk of data if CacheProvider was specified
	case cacheData(CacheProviderType)
	/// This event will be sended after receiving new chunk of data if CacheProvider was not specified
	case receiveData(NSData)
	// This event will be sended after receiving response
	case receiveResponse(NSHTTPURLResponseType)
	case error(ErrorType)
	case success(cache: CacheProviderType?)
}

public protocol StreamDataTaskType : StreamTaskType {
	var taskProgress: Observable<StreamTaskEvents> { get }
	var cacheProvider: CacheProviderType? { get }
}

public final class StreamDataTask {
	public let uid: String
	public internal (set) var resumed = false
	public internal(set) var cacheProvider: CacheProviderType?

	internal let queue = dispatch_queue_create("StreamDataTask.SerialQueue", DISPATCH_QUEUE_SERIAL)
	internal let httpClient: HttpClientType
	internal var response: NSHTTPURLResponseType?
	internal let scheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	internal let dataTask: NSURLSessionDataTaskType
	internal let sessionEvents: Observable<SessionDataEvents>

	public init(taskUid: String, dataTask: NSURLSessionDataTaskType, httpClient: HttpClientType, sessionEvents: Observable<SessionDataEvents>,
	            cacheProvider: CacheProviderType?) {
		self.dataTask = dataTask
		self.httpClient = httpClient
		self.sessionEvents = sessionEvents
		self.cacheProvider = cacheProvider
		uid = taskUid
	}
	
	public lazy var taskProgress: Observable<StreamTaskEvents> = {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			let disposable = object.sessionEvents.observeOn(object.scheduler).bindNext { e in
					switch e {
					case .didReceiveResponse(_, let task, let response, let completionHandler):
						guard let response = response as? NSHTTPURLResponseType else { return }
						
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						
						completionHandler(.Allow)
						
						object.response = response
						object.cacheProvider?.expectedDataLength = response.expectedContentLength
						object.cacheProvider?.setContentMimeTypeIfEmpty(response.getMimeType())
						observer.onNext(StreamTaskEvents.receiveResponse(response))
					case .didReceiveData(_, let task, let data):
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						
						if let cacheProvider = object.cacheProvider {
							cacheProvider.appendData(data)
							observer.onNext(StreamTaskEvents.cacheData(cacheProvider))
						} else {
							observer.onNext(StreamTaskEvents.receiveData(data))
						}
					case .didCompleteWithError(let session, let task, let error):
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						
						object.resumed = false
						
						if let error = error {
							observer.onNext(StreamTaskEvents.error(error))
						} else {
							observer.onNext(StreamTaskEvents.success(cache: object.cacheProvider))
						}

						observer.onCompleted()
					}
			}
			
			return AnonymousDisposable {
				disposable.dispose()
			}
		}.shareReplay(0)
	}()
}

extension StreamDataTask : StreamDataTaskType {
	public func resume() {
		dispatch_sync(queue) {
			if !self.resumed { self.resumed = true; self.dataTask.resume() }
		}
	}
	
	/*
	public func suspend() {
		self.resumed = false
		dataTask.suspend()
	}
	*/
	
	public func cancel() {
		resumed = false
		dataTask.cancel()
	}
}