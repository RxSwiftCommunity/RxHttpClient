import Foundation

protocol HttpUtilitiesType {
	func createUrlRequest(baseUrl: String, parameters: [String: String]?) -> NSMutableURLRequestType?
	func createUrlRequest(baseUrl: String, parameters: [String: String]?, headers: [String: String]?) -> NSMutableURLRequestType?
	func createUrlRequest(url: NSURL, headers: [String: String]?) -> NSMutableURLRequestType
	func createUrlSession(configuration: NSURLSessionConfiguration, delegate: NSURLSessionDelegate?, queue: NSOperationQueue?) -> NSURLSessionType
	func createUrlSessionStreamObserver() -> NSURLSessionDataEventsObserverType
	func createStreamDataTask(taskUid: String, request: NSMutableURLRequestType, sessionConfiguration: NSURLSessionConfiguration, cacheProvider: CacheProviderType?)
		-> StreamDataTaskType
}

class HttpUtilities { }

extension HttpUtilities : HttpUtilitiesType {
	func createUrlRequest(baseUrl: String, parameters: [String : String]?) -> NSMutableURLRequestType? {
		guard let url = NSURL(baseUrl: baseUrl, parameters: parameters) else {
			return nil
		}
		return createUrlRequest(url)
	}
	
	func createUrlRequest(baseUrl: String, parameters: [String: String]?, headers: [String: String]?) -> NSMutableURLRequestType? {
		guard let url = NSURL(baseUrl: baseUrl, parameters: parameters) else {
			return nil
		}
		
		return createUrlRequest(url, headers: headers)
	}
	
	func createUrlRequest(url: NSURL, headers: [String : String]? = nil) -> NSMutableURLRequestType {
		let request = NSMutableURLRequest(URL: url)
		headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
		return request
	}
	
	func createUrlSession(configuration: NSURLSessionConfiguration, delegate: NSURLSessionDelegate? = nil, queue: NSOperationQueue? = nil)
		-> NSURLSessionType {
		return NSURLSession(configuration: configuration,
			delegate: delegate,
			delegateQueue: queue)
	}
	
	func createUrlSessionStreamObserver() -> NSURLSessionDataEventsObserverType {
		return NSURLSessionDataEventsObserver()
	}
	
	func createStreamDataTask(taskUid: String, request: NSMutableURLRequestType,
	                                 sessionConfiguration: NSURLSessionConfiguration = .defaultSessionConfiguration(), cacheProvider: CacheProviderType?) -> StreamDataTaskType {
		return StreamDataTask(taskUid: taskUid, request: request, httpUtilities: self, sessionConfiguration: sessionConfiguration, cacheProvider: cacheProvider)
	}
}