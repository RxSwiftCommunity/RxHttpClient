import Foundation
import RxSwift

public extension HttpClientType {
	/**
	Creates NSMutableURLRequest with provided NSURL and HTTP Headers
	- parameter url: Url for request
	- parameter headers: Additional HTTP Headers
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: URL, headers: [String: String]?) -> URLRequest {
		var request = URLRequest(url: url)
		headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
		return request
	}
	
	/**
	Creates NSMutableURLRequest with provided NSURL
	- parameter url: Url for request
	- returns: Created mutable url request
	*/
	func createUrlRequest(url: URL) -> URLRequest {
		return createUrlRequest(url: url, headers: nil)
	}
	
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(request: URLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return createStreamDataTask(taskUid: UUID().uuidString, request: request, cacheProvider: cacheProvider)
	}
	
	/**
	Creates streaming observable for URL
	- parameter request: URL
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable that emits stream events
	*/
	func request(url: URL, cacheProvider: CacheProviderType? = nil) -> Observable<StreamTaskEvents> {
		return request(createUrlRequest(url: url), cacheProvider: cacheProvider)
	}
	
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- returns: Created observable that emits stream events
	*/
	func request(_ urlRequest: URLRequest) -> Observable<StreamTaskEvents> {
		return request(urlRequest, cacheProvider: nil)
	}
	
	/**
	Creates an observable for URL
	- parameter request: URL
	- returns: Created observable that emits Data of HTTP request
	*/
	func requestData(url: URL) -> Observable<Data> {
		return requestData(createUrlRequest(url: url))
	}
	
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable that emits Data of HTTP request
	*/
	func requestData(_ urlRequest: URLRequest)	-> Observable<Data> {
		// provider for caching data
		let cacheProvider = MemoryCacheProvider(uid: UUID().uuidString)
		// variable for response with error
		var errorResponse: HTTPURLResponse? = nil

		return request(urlRequest, cacheProvider: cacheProvider)
			.flatMapLatest { result -> Observable<Data> in
				switch result {
				case .error(let error):
					// checking error type
					guard error is HttpClientError else {
						// if it's not HttpClientError wrap it on ClientSideError
						return Observable.error(HttpClientError.clientSideError(error: error as NSError))
					}
					// otherwise forward error
					return Observable.error(error)
				case .receiveResponse(let response as HTTPURLResponse) where !(200...299 ~= response.statusCode):
					// checking status code of HTTP responce, and caching response if code is not success (not 2xx)
					// saving response
					errorResponse = response
					return Observable.empty()
				case .success:
					guard let errorResponse = errorResponse else {
						// if we don't have errorResponse, request completed successfuly and we simply return data
						return Observable.just(cacheProvider.getData())
					}
					
					return Observable.error(HttpClientError.invalidResponse(response: errorResponse, data: cacheProvider.getData()))
				default: return Observable.empty()
				}
		}
	}
}
