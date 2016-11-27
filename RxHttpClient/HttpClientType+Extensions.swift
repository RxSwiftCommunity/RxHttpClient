import Foundation
import RxSwift

public struct CacheMode {
	let cacheResponse: Bool
	let returnCachedResponse: Bool
	let invokeRequest: Bool
	
	init(cacheResponse: Bool = true, returnCachedResponse: Bool = true, invokeRequest: Bool = true) {
		self.cacheResponse = cacheResponse
		self.returnCachedResponse = returnCachedResponse
		self.invokeRequest = invokeRequest
	}
	
	static let cacheOnly = { return CacheMode(cacheResponse: false, returnCachedResponse: true, invokeRequest: false) }()
	static let withoutCache = { return CacheMode(cacheResponse: true, returnCachedResponse: false, invokeRequest: true) }()
	static let notCacheResponse = { return CacheMode(cacheResponse: false, returnCachedResponse: false, invokeRequest: true) }()
}

public extension HttpClientType {	
	/**
	Creates StreamDataTask
	- parameter request: URL request
	- parameter dataCacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(request: URLRequest, dataCacheProvider: DataCacheProviderType?) -> StreamDataTaskType {
		return createStreamDataTask(taskUid: UUID().uuidString, request: request, dataCacheProvider: dataCacheProvider)
	}
	
	/**
	Creates streaming observable for URL
	- parameter request: URL
	- parameter dataCacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable that emits stream events
	*/
	func request(url: URL, dataCacheProvider: DataCacheProviderType? = nil) -> Observable<StreamTaskEvents> {
		return request(URLRequest(url: url), dataCacheProvider: dataCacheProvider)
	}
	
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- returns: Created observable that emits stream events
	*/
	func request(_ urlRequest: URLRequest) -> Observable<StreamTaskEvents> {
		return request(urlRequest, dataCacheProvider: nil)
	}
	
	/**
	Creates streaming observable for URL
	- parameter request: URL
	- returns: Created observable that emits deserialized JSON object of HTTP request
	*/
	func requestJson(url: URL, requestCacheMode: CacheMode = CacheMode()) -> Observable<Any> {
		return requestJson(URLRequest(url: url), requestCacheMode: requestCacheMode)
	}
	
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- returns: Created observable that emits deserialized JSON object of HTTP request
	*/
	func requestJson(_ urlRequest: URLRequest, requestCacheMode: CacheMode = CacheMode()) -> Observable<Any> {
		return requestData(urlRequest, requestCacheMode: requestCacheMode).flatMapLatest { data -> Observable<Any> in
			guard data.count > 0 else { return Observable.empty() }
			
			do {
				return Observable.just(try JSONSerialization.jsonObject(with: data, options: []))
			} catch(let error) {
				return Observable.error(HttpClientError.jsonDeserializationError(error: error))
			}
		}
	}
	
	/**
	Creates an observable for URL
	- parameter request: URL
	- returns: Created observable that emits Data of HTTP request
	*/
	func requestData(url: URL, requestCacheMode: CacheMode = CacheMode()) -> Observable<Data> {
		return requestData(URLRequest(url: url), requestCacheMode: requestCacheMode)
	}
	
	/**
	Creates an observable for request
	- parameter request: URL request
	- returns: Created observable that emits Data of HTTP request
	*/
	func requestData(_ urlRequest: URLRequest, requestCacheMode: CacheMode = CacheMode())	-> Observable<Data> {
		// provider for caching data
		let dataCacheProvider = MemoryDataCacheProvider(uid: UUID().uuidString)
		// variable for response with error
		var errorResponse: HTTPURLResponse? = nil
		
		let cachedRequest: Observable<Data> = {
			if requestCacheMode.returnCachedResponse, let url = urlRequest.url, let cached = urlRequestCacheProvider?.load(resourceUrl: url) {
					return Observable.just(cached)
			}
			return Observable.empty()
		}()
		
		guard requestCacheMode.invokeRequest else {
			return cachedRequest
		}

		return cachedRequest.concat(request(urlRequest, dataCacheProvider: dataCacheProvider)
			.flatMapLatest { [weak self] result -> Observable<Data> in
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
						let requestData = dataCacheProvider.getData()
						
						if requestCacheMode.cacheResponse, let url = urlRequest.url  {
							self?.urlRequestCacheProvider?.save(resourceUrl: url, data: requestData)
						}
						
						// if we don't have errorResponse, request completed successfuly and we simply return data
						return Observable.just(requestData)
					}
					
					return Observable.error(HttpClientError.invalidResponse(response: errorResponse, data: dataCacheProvider.getData()))
				default: return Observable.empty()
				}
		})
	}
}
