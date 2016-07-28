import Foundation
import RxSwift

public extension HttpClientType {
	/**
	Creates NSMutableURLRequest with provided NSURL and HTTP Headers
	- parameter url: Url for request
	- parameter headers: Additional HTTP Headers
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequest {
		let request = NSMutableURLRequest(URL: url)
		headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
		return request
	}
	
	/**
	Creates NSMutableURLRequest with provided NSURL
	- parameter url: Url for request
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: NSURL) -> NSMutableURLRequest {
		return createUrlRequest(url, headers: nil)
	}
	
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(request: NSURLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return createStreamDataTask(NSUUID().UUIDString, request: request, cacheProvider: cacheProvider)
	}
	
	/**
	Creates an observable for URL
	- parameter request: URL
	- returns: Created observable that emits HTTP request result events
	*/
	func loadData(url: NSURL) -> Observable<HttpRequestResult> {
		return loadData(createUrlRequest(url))
	}
	
	/**
	Creates streaming observable for URL
	- parameter request: URL
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable that emits stream events
	*/
	func loadStreamData(url: NSURL, cacheProvider: CacheProviderType? = nil) -> Observable<StreamTaskEvents> {
		return loadStreamData(createUrlRequest(url), cacheProvider: cacheProvider)
	}
	
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable that emits HTTP request result events
	*/
	func loadData(request: NSURLRequest)	-> Observable<HttpRequestResult> {
		return loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString))
			.flatMapLatest { result -> Observable<HttpRequestResult> in
				if case StreamTaskEvents.error(let error) = result {
					return Observable.just(.error(error))
				}
				
				guard case StreamTaskEvents.success(let cache) = result else { return Observable.empty() }
				
				guard let cacheProvider = cache where cacheProvider.currentDataLength > 0 else { return Observable.just(.success) }
				
				return Observable.just(.successData(cacheProvider.getCurrentData()))
		}
	}
}