import Foundation
import RxSwift

public enum HttpRequestResult {
	case success
	case successData(NSData)
	case error(ErrorType)
}

public protocol HttpClientType {
	var httpUtilities: HttpUtilitiesType { get }
	func loadData(request: NSMutableURLRequestType) -> Observable<HttpRequestResult>
	func loadStreamData(request: NSMutableURLRequestType, cacheProvider: CacheProviderType?) -> Observable<StreamTaskResult>
}

public class HttpClient {
	public let httpUtilities: HttpUtilitiesType
	internal let scheduler = SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
	
	public init(httpUtilities: HttpUtilitiesType = HttpUtilities()) {
		
		self.httpUtilities = httpUtilities
	}
}

extension HttpClient : HttpClientType {
	public func loadData(request: NSMutableURLRequestType)
		-> Observable<HttpRequestResult> {
			return Observable.create { [weak self] observer in
				guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
				
				let task = object.httpUtilities.createStreamDataTask(NSUUID().UUIDString,
					request: request, sessionConfiguration: NSURLSession.defaultConfig, cacheProvider: nil)
				
				let receivedData = NSMutableData()
				
				let disposable = task.taskProgress.catchError { error in
					observer.onNext(.error(error))
					observer.onCompleted()
					return Observable.empty()
					}.doOnCompleted { observer.onCompleted() }.bindNext { result in
						if case Result.success(let box) = result {
							if case StreamTaskEvents.ReceiveData(let data) = box.value {
								receivedData.appendData(data)
							} else if case StreamTaskEvents.Success = box.value {
								if receivedData.length > 0 {
									observer.onNext(.successData(receivedData))
								} else {
									observer.onNext(.success)
								}
							}
						} else if case Result.error(let error) = result {
							observer.onNext(.error(error))
						}
				}
				
				task.resume()
				
				return AnonymousDisposable {
					task.cancel()
					disposable.dispose()
				}
			}.observeOn(scheduler).shareReplay(0)
	}
	
	public func loadStreamData(request: NSMutableURLRequestType, cacheProvider: CacheProviderType?)
		-> Observable<StreamTaskResult> {
		return Observable.create { [weak self] observer in
			guard let object = self else { observer.onCompleted(); return NopDisposable.instance }
			
			let task = object.httpUtilities.createStreamDataTask(NSUUID().UUIDString, request: request, sessionConfiguration: NSURLSession.defaultConfig,
				cacheProvider: cacheProvider)
				
			let disposable = task.taskProgress.catchError { error in
				observer.onNext(Result.error(error))
				observer.onCompleted()
				return Observable.empty()
			}.bindNext { result in
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
}