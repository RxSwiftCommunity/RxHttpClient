import Foundation
import RxSwift
import RxCocoa

public protocol StreamTaskType {
	var uid: String { get }
	func resume()
	//func suspend()
	func cancel()
	var resumed: Bool { get }
}

public typealias StreamTaskResult = Result<StreamTaskEvents>

public enum StreamTaskEvents {
	/// Send this event if CacheProvider specified
	case CacheData(CacheProviderType)
	/// Send this event only if CacheProvider is nil
	case ReceiveData(NSData)
	case ReceiveResponse(NSHTTPURLResponseType)
	//case Error(NSError)
	case Success(cache: CacheProviderType?)
}

extension StreamTaskEvents {
	func asResult() -> StreamTaskResult {
		return Result.success(Box(value: self))
	}
}

public protocol StreamDataTaskType : StreamTaskType {
	var taskProgress: Observable<StreamTaskResult> { get }
	var cacheProvider: CacheProviderType? { get }
}

public class StreamDataTask {
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
	
	public lazy var taskProgress: Observable<StreamTaskResult> = {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			let disposable = object.sessionEvents.observeOn(object.scheduler).filter { e in
				if case .didReceiveResponse(_, let task, let response, let completionHandler) = e {
					guard task.isEqual(object.dataTask as? AnyObject) else { return true }
					completionHandler(.Allow)
					return response as? NSHTTPURLResponseType != nil
				} else { return true }
				}.bindNext { e in
					switch e {
					case .didReceiveResponse(_, let task, let response, _):
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						object.response = response as? NSHTTPURLResponseType
						object.cacheProvider?.expectedDataLength = object.response!.expectedContentLength
						object.cacheProvider?.setContentMimeTypeIfEmpty(object.response!.getMimeType())
						observer.onNext(StreamTaskEvents.ReceiveResponse(object.response!).asResult())
					case .didReceiveData(_, let task, let data):
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						
						if let cacheProvider = object.cacheProvider {
							cacheProvider.appendData(data)
							observer.onNext(StreamTaskEvents.CacheData(cacheProvider).asResult())
						} else {
							observer.onNext(StreamTaskEvents.ReceiveData(data).asResult())
						}
					case .didCompleteWithError(let session, let task, let error):
						guard task.isEqual(object.dataTask as? AnyObject) else { return }
						
						object.resumed = false
						
						if let error = error {
							observer.onNext(Result.error(error))
						} else {
							observer.onNext(StreamTaskEvents.Success(cache: object.cacheProvider).asResult())
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