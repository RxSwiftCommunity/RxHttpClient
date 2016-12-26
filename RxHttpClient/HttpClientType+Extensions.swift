import Foundation
import RxSwift

/// Represents caching settings
public struct CacheMode {
    /// If true, response for GET request will be cached
    public let cacheResponse: Bool
    /// If true, HttpClient will immediately return cacged respons if it exists
    public let returnCachedResponse: Bool
    /// If true, HttpClient will invoke request
    public let invokeRequest: Bool
    
    public init(cacheResponse: Bool = true, returnCachedResponse: Bool = true, invokeRequest: Bool = true) {
        self.cacheResponse = cacheResponse
        self.returnCachedResponse = returnCachedResponse
        self.invokeRequest = invokeRequest
    }
    
    /// Only cached response will be returned
    public static let cacheOnly = CacheMode(cacheResponse: false, returnCachedResponse: true, invokeRequest: false)
    /// Cached response will not be returned even if exists
    public static let withoutCache = CacheMode(cacheResponse: true, returnCachedResponse: false, invokeRequest: true)
    /// Response will not be cached
    public static let notCacheResponse = CacheMode(cacheResponse: false, returnCachedResponse: false, invokeRequest: true)
    /// All conditions are true
    public static let `default` = CacheMode(cacheResponse: true, returnCachedResponse: true, invokeRequest: true)
}

public extension HttpClientType {
    /**
     Creates StreamDataTask
     - parameter request: URL request
     - parameter dataCacheProvider: Cache provider, that will be used to cache downloaded data
     - returns: Created data task
     */
    func createStreamDataTask(request: URLRequest, dataCacheProvider: DataCacheProviderType? = nil) -> StreamDataTaskType {
        return createStreamDataTask(taskUid: UUID().uuidString, request: request, dataCacheProvider: dataCacheProvider)
    }
    
    /**
     Creates streaming observable for URL
     - parameter request: URL
     - parameter method: HTTP method for request
     - parameter body: Data that will be set to httpBody property of URLRequest
     - parameter httpHeaders: HTTP headers for request
     - parameter dataCacheProvider: Cache provider, that will be used to cache downloaded data
     - returns: Created observable that emits stream events
     */
    func request(url: URL, method: HttpMethod = .get, body: Data? = nil, httpHeaders: [String: String] = [:],
                 dataCacheProvider: DataCacheProviderType? = nil) -> Observable<StreamTaskEvents> {
        return request(URLRequest(url: url, method: method, body: body, headers: httpHeaders), dataCacheProvider: dataCacheProvider)
    }
    
    /**
     Creates streaming observable for URL
     - parameter request: URL
     - parameter method: HTTP method for request
     - parameter body: Data that will be set to httpBody property of URLRequest
     - parameter httpHeaders: HTTP headers for request
     - parameter requestCacheMode: CacheMode for request
     - returns: Created observable that emits deserialized JSON object of HTTP request
     */
    func requestJson(url: URL, method: HttpMethod = .get, body: Data? = nil, httpHeaders: [String: String] = [:],
                     requestCacheMode: CacheMode = CacheMode()) -> Observable<Any> {
        return requestJson(URLRequest(url: url, method: method, body: body, headers: httpHeaders), requestCacheMode: requestCacheMode)
    }
    
    /**
     Creates streaming observable for request
     - parameter request: URL request
     - parameter requestCacheMode: CacheMode for request
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
     - parameter method: HTTP method for request
     - parameter body: Data that will be set to httpBody property of URLRequest
     - parameter httpHeaders: HTTP headers for request
     - parameter requestCacheMode: CacheMode for request
     - returns: Created observable that emits Data of HTTP request
     */
    func requestData(url: URL, method: HttpMethod = .get, body: Data? = nil, httpHeaders: [String: String] = [:],
                     requestCacheMode: CacheMode = CacheMode()) -> Observable<Data> {
        return requestData(URLRequest(url: url, method: method, body: body, headers: httpHeaders), requestCacheMode: requestCacheMode)
    }
    
    /**
     Creates an observable for request
     - parameter request: URL request
     - parameter requestCacheMode: CacheMode for request
     - returns: Created observable that emits Data of HTTP request
     */
    func requestData(_ urlRequest: URLRequest, requestCacheMode: CacheMode = CacheMode())	-> Observable<Data> {
        // provider for caching data
        let dataCacheProvider = MemoryDataCacheProvider(uid: UUID().uuidString)
        // variable for response with error
        var errorResponse: HTTPURLResponse? = nil
        
        let cachedRequest: Observable<Data> = {
            if urlRequest.httpMethod == HttpMethod.get.rawValue, requestCacheMode.returnCachedResponse, let url = urlRequest.url, let cached = urlRequestCacheProvider?.load(resourceUrl: url) {
                // return cached response
                return Observable.just(cached)
            }
            return Observable.empty()
        }()
        
        guard requestCacheMode.invokeRequest else {
            // if we should not invoke request, simply return cache request
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
                        
                        if urlRequest.httpMethod == HttpMethod.get.rawValue, requestCacheMode.cacheResponse, let url = urlRequest.url  {
                            // sache response
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
