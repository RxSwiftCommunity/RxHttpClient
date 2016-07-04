import Foundation
import RxSwift
import RxCocoa

public protocol StreamTaskProtocol {
	var uid: String { get }
	func resume()
	func suspend()
	func cancel()
	var resumed: Bool { get }
}

public protocol StreamTaskEventsProtocol { }

public typealias StreamTaskResult = Result<StreamTaskEvents>

public enum StreamTaskEvents : StreamTaskEventsProtocol {
	/// Send this event if CacheProvider specified
	case CacheData(CacheProvider)
	/// Send this event only if CacheProvider is nil
	case ReceiveData(NSData)
	case ReceiveResponse(NSHTTPURLResponseProtocol)
	//case Error(NSError)
	case Success(cache: CacheProvider?)
}

extension StreamTaskEvents {
	public func asResult() -> StreamTaskResult {
		return Result.success(Box(value: self))
	}
}

public protocol StreamDataTaskProtocol : StreamTaskProtocol {
	var taskProgress: Observable<StreamTaskResult> { get }
	var cacheProvider: CacheProvider? { get }
}

public class StreamDataTask {
	internal let queue = dispatch_queue_create("com.cloudmusicplayer.streamdatatask.serialqueue.\(NSUUID().UUIDString)", DISPATCH_QUEUE_SERIAL)
	public let uid: String
	public var resumed = false
	
	public let request: NSMutableURLRequestProtocol
	public let httpUtilities: HttpUtilitiesProtocol
	public let sessionConfiguration: NSURLSessionConfiguration
	public internal(set) var cacheProvider: CacheProvider?
	internal var response: NSHTTPURLResponseProtocol?
	internal let scheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
		
	internal lazy var dataTask: NSURLSessionDataTaskProtocol = { [unowned self] in
		return self.session.dataTaskWithRequest(self.request)
		}()
	
	internal lazy var observer: NSURLSessionDataEventsObserverProtocol = { [unowned self] in
			return self.httpUtilities.createUrlSessionStreamObserver()
		}()
	
	internal lazy var session: NSURLSessionProtocol = { [unowned self] in
		return self.httpUtilities.createUrlSession(self.sessionConfiguration, delegate: self.observer as? NSURLSessionDataDelegate, queue: nil)
		}()
	
	public init(taskUid: String, request: NSMutableURLRequestProtocol, httpUtilities: HttpUtilitiesProtocol,
	            sessionConfiguration: NSURLSessionConfiguration, cacheProvider: CacheProvider?) {
		self.request = request
		self.httpUtilities = httpUtilities
		self.sessionConfiguration = sessionConfiguration
		self.cacheProvider = cacheProvider
		uid = taskUid
	}
	
	public lazy var taskProgress: Observable<StreamTaskResult> = {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			let disposable = object.observer.sessionEvents.observeOn(object.scheduler).filter { e in
				if case .didReceiveResponse(_, _, let response, let completionHandler) = e {
					completionHandler(.Allow)
					return response as? NSHTTPURLResponseProtocol != nil
				} else { return true }
				}.bindNext { e in
					switch e {
					case .didReceiveResponse(_, _, let response, _):
						object.response = response as? NSHTTPURLResponseProtocol
						object.cacheProvider?.expectedDataLength = object.response!.expectedContentLength
						object.cacheProvider?.setContentMimeTypeIfEmpty(object.response!.getMimeType())
						observer.onNext(StreamTaskEvents.ReceiveResponse(object.response!).asResult())
					case .didReceiveData(_, _, let data):
						if let cacheProvider = object.cacheProvider {
							cacheProvider.appendData(data)
							observer.onNext(StreamTaskEvents.CacheData(cacheProvider).asResult())
						} else {
							observer.onNext(StreamTaskEvents.ReceiveData(data).asResult())
						}
					case .didCompleteWithError(let session, _, let error):
						session.invalidateAndCancel()
						
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

extension StreamDataTask : StreamDataTaskProtocol {
	public func resume() {
		dispatch_sync(queue) {
			if !self.resumed { self.resumed = true; self.dataTask.resume() }
		}
	}
	
	public func suspend() {
		self.resumed = false
		dataTask.suspend()
	}
	
	public func cancel() {
		resumed = false
		dataTask.cancel()
		session.invalidateAndCancel()
	}
}