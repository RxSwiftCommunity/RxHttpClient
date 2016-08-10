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
	func loadData(url: NSURL) -> Observable<NSData> {
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
	func loadData(request: NSURLRequest)	-> Observable<NSData> {
		// provider for caching data
		let cacheProvider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		// variable for response with error
		var errorResponse: NSHTTPURLResponse? = nil
		
		return loadStreamData(request, cacheProvider: cacheProvider)
			.flatMapLatest { result -> Observable<NSData> in
				switch result {
				case .Error(let error):
					// checking error type
					guard error is HttpClientError else {
						// if it's not HttpClientError wrap it on ClientSideError
						return Observable.error(HttpClientError.ClientSideError(error: error as NSError))
					}
					// otherwise forward error
					return Observable.error(error)
				case .ReceiveResponse(let response as NSHTTPURLResponse) where !(200...299 ~= response.statusCode):
					// checking status code of HTTP responce, and caching response if code is not success (not 2xx)
					// saving response
					errorResponse = response
					return Observable.empty()
				case .Success:
					guard let errorResponse = errorResponse else {
						// if we don't have errorResponse, request completed successfuly and we simply return data
						return Observable.just(cacheProvider.getCurrentData())
					}
					
					return Observable.error(HttpClientError.InvalidResponse(response: errorResponse, data: cacheProvider.getCurrentData()))
				default: return Observable.empty()
				}
		}
	}
}