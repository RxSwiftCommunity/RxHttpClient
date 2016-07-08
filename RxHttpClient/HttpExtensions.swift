import Foundation


// NSHTTPURLResponseProtocol
public protocol NSHTTPURLResponseType {
	var expectedContentLength: Int64 { get }
	var MIMEType: String? { get }
	func getMimeType() -> String
}
extension NSHTTPURLResponse : NSHTTPURLResponseType { }
extension NSHTTPURLResponseType {
	public func getMimeType() -> String {
		return MIMEType ?? ""
	}
}

// NSURLResponse
public protocol NSURLResponseType { }
extension NSURLResponse : NSURLResponseType { }


// NSURLRequestProtocol
public protocol NSURLRequestType {
	var HTTPMethod: String? { get }
}
extension NSURLRequest : NSURLRequestType { }


// NSMutableURLRequestProtocol
public protocol NSMutableURLRequestType : NSURLRequestType {
	func addValue(value: String, forHTTPHeaderField: String)
	var URL: NSURL? { get }
	var allHTTPHeaderFields: [String: String]? { get }
	func setHttpMethod(method: String)
}
extension NSMutableURLRequest : NSMutableURLRequestType {
	public func setHttpMethod(method: String) {
		HTTPMethod = method
	}
}


public protocol NSURLSessionTaskType { }
extension NSURLSessionTask : NSURLSessionTaskType { }

// NSURLSessionDataTaskProtocol
public protocol NSURLSessionDataTaskType : NSURLSessionTaskType {
	func resume()
	func suspend()
	func cancel()
	func getOriginalMutableUrlRequest() -> NSMutableURLRequestType?
}
extension NSURLSessionDataTask : NSURLSessionDataTaskType {
	public func getOriginalMutableUrlRequest() -> NSMutableURLRequestType? {
		return originalRequest as? NSMutableURLRequestType
	}
}


// NSURLSessionProtocol
public typealias DataTaskResult = (NSData?, NSURLResponse?, NSError?) -> Void
public protocol NSURLSessionType {
	var configuration: NSURLSessionConfiguration { get }
	func invalidateAndCancel()
	func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult)	-> NSURLSessionDataTaskType
	func dataTaskWithRequest(request: NSMutableURLRequestType, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType
	func dataTaskWithRequest(request: NSMutableURLRequestType) -> NSURLSessionDataTaskType
}
extension NSURLSession : NSURLSessionType {
	public func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		return dataTaskWithURL(url, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestType, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		return dataTaskWithRequest(request as! NSMutableURLRequest, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestType) -> NSURLSessionDataTaskType {
		return dataTaskWithRequest(request as! NSURLRequest) as NSURLSessionDataTask
	}
}
extension NSURLSession {
	public static var defaultConfig: NSURLSessionConfiguration {
		return .defaultSessionConfiguration()
	}
}


// NSURL
extension NSURL {
	public convenience init?(baseUrl: String, parameters: [String: String]?) {
		if let parameters = parameters, components = NSURLComponents(string: baseUrl) {
			components.queryItems = [NSURLQueryItem]()
			parameters.forEach { key, value in
				components.queryItems?.append(NSURLQueryItem(name: key, value: value))
			}
			self.init(string: components.URL!.absoluteString)
		} else {
			self.init(string: baseUrl)
		}
	}
	
	public func isEqualsToUrl(url: NSURL) -> Bool {
		if let params1 = query, params2 = url.query {
			let par1 = params1.characters.split { $0 == "&" }.map(String.init)
			let par2 = params2.characters.split { $0 == "&" }.map(String.init)
			if par1.sort() == par2.sort() {
				return absoluteString.stringByReplacingOccurrencesOfString(params1, withString: "") ==
					url.absoluteString.stringByReplacingOccurrencesOfString(params2, withString: "")
			} else {
				return false
			}
		}
		return self == url
	}
}