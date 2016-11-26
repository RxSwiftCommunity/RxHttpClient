import Foundation
import RxSwift

public enum StreamTaskState : Int {
	case running
	case suspended
	case completed
}

public protocol StreamTaskType {
	/// Identifier of a task.
	var uid: String { get }
	/// Resumes task.
	func resume()
	/// Cancels task.
	func cancel()
	var state: StreamTaskState  { get }
}

public protocol StreamDataTaskType : StreamTaskType {
	/// Observable sequence, that emits events associated with underlying data task.
	var taskProgress: Observable<StreamTaskEvents> { get }
	/// Instance of cache provider, associated with this task.
	var cacheProvider: DataCacheProviderType? { get }
}

/**
Represents the events that will be sended to observers of StreamDataTask
*/
public enum StreamTaskEvents {
	/// This event will be sended after receiving (and cacnhing) new chunk of data. 
	/// This event will be sended only if CacheProvider was specified.
	case cacheData(DataCacheProviderType)
	/// This event will be sended after receiving new chunk of data.
	/// This event will be sended only if CacheProvider was not specified.
	case receiveData(Data)
	// This event will be sended after receiving response.
	case receiveResponse(URLResponse)
	/**
	This event will be sended if underlying task was completed with error.
	This event will be sended if unerlying NSURLSession invoked delegate method URLSession:task:didCompleteWithError: with specified error.
	*/
	case error(Error)
	/// This event will be sended after completion of underlying data task.
	case success(cache: DataCacheProviderType?)
}

internal final class StreamDataTask {
	let uid: String
	var state: StreamTaskState = .suspended
	var cacheProvider: DataCacheProviderType?

	var response: URLResponse?
	let scheduler = SerialDispatchQueueScheduler(qos: .utility)
	let dataTask: URLSessionDataTaskType
	let sessionEvents: Observable<SessionDataEvents>

	init(taskUid: String, dataTask: URLSessionDataTaskType, sessionEvents: Observable<SessionDataEvents>,
	            cacheProvider: DataCacheProviderType?) {
		self.dataTask = dataTask
		self.sessionEvents = sessionEvents
		self.cacheProvider = cacheProvider
		uid = taskUid
	}
	
	lazy var taskProgress: Observable<StreamTaskEvents> = {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return Disposables.create() }
			
			let disposable = object.sessionEvents.observeOn(object.scheduler).subscribe(onNext: { e in
					switch e {
					case .didReceiveResponse(_, let task, let response, let completionHandler):
						guard task.isEqual(object.dataTask) else { return }
						
						completionHandler(.allow)
						
						object.response = response
						object.cacheProvider?.expectedDataLength = response.expectedContentLength
						object.cacheProvider?.setContentMimeTypeIfEmpty(mimeType: response.mimeType ?? "")
						observer.onNext(StreamTaskEvents.receiveResponse(response))
					case .didReceiveData(_, let task, let data):
						guard task.isEqual(object.dataTask) else { return }
						
						if let cacheProvider = object.cacheProvider {
							cacheProvider.append(data: data)
							observer.onNext(StreamTaskEvents.cacheData(cacheProvider))
						} else {
							observer.onNext(StreamTaskEvents.receiveData(data))
						}
					case .didCompleteWithError(let session, let task, let error):
						guard task.isEqual(object.dataTask) else { return }
						
						if let error = error {
							object.state = .suspended
							observer.onNext(StreamTaskEvents.error(error))
						} else {
							object.state = .completed
							observer.onNext(StreamTaskEvents.success(cache: object.cacheProvider))
						}

						observer.onCompleted()
					case .didBecomeInvalidWithError(_, let error):
						object.state = .suspended						
						// dealing with session invalidation
						guard let error = error else {
							// if error is nil, session was invalidated explicitly
							observer.onNext(StreamTaskEvents.error(HttpClientError.sessionExplicitlyInvalidated))
							return
						}
						// otherwise sending error that caused invalidation
						observer.onNext(StreamTaskEvents.error(HttpClientError.sessionInvalidatedWithError(error: error)))
					}
			})
			
			return Disposables.create {
				disposable.dispose()
			}
		}.shareReplay(0)
	}()
}

extension StreamDataTask : StreamDataTaskType {
	func resume() {
		state = .running
		dataTask.resume()
	}
		
	func cancel() {
		state = .suspended
		dataTask.cancel()
	}
}
