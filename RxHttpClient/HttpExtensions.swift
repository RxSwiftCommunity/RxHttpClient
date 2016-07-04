import Foundation


// NSHTTPURLResponseProtocol
public protocol NSHTTPURLResponseProtocol {
	var expectedContentLength: Int64 { get }
	var MIMEType: String? { get }
	func getMimeType() -> String
}
extension NSHTTPURLResponse : NSHTTPURLResponseProtocol { }
extension NSHTTPURLResponseProtocol {
	public func getMimeType() -> String {
		return MIMEType ?? ""
	}
}

// NSURLResponse
public protocol NSURLResponseProtocol { }
extension NSURLResponse : NSURLResponseProtocol { }


// NSURLRequestProtocol
public protocol NSURLRequestProtocol {
	var HTTPMethod: String? { get }
}
extension NSURLRequest : NSURLRequestProtocol { }


// NSMutableURLRequestProtocol
public protocol NSMutableURLRequestProtocol : NSURLRequestProtocol {
	func addValue(value: String, forHTTPHeaderField: String)
	var URL: NSURL? { get }
	var allHTTPHeaderFields: [String: String]? { get }
	func setHttpMethod(method: String)
}
extension NSMutableURLRequest : NSMutableURLRequestProtocol {
	public func setHttpMethod(method: String) {
		HTTPMethod = method
	}
}


public protocol NSURLSessionTaskProtocol { }
extension NSURLSessionTask : NSURLSessionTaskProtocol { }

// NSURLSessionDataTaskProtocol
public protocol NSURLSessionDataTaskProtocol : NSURLSessionTaskProtocol {
	func resume()
	func suspend()
	func cancel()
	func getOriginalMutableUrlRequest() -> NSMutableURLRequestProtocol?
}
extension NSURLSessionDataTask : NSURLSessionDataTaskProtocol {
	public func getOriginalMutableUrlRequest() -> NSMutableURLRequestProtocol? {
		return originalRequest as? NSMutableURLRequestProtocol
	}
}


// NSURLSessionProtocol
public typealias DataTaskResult = (NSData?, NSURLResponse?, NSError?) -> Void
public protocol NSURLSessionProtocol {
	var configuration: NSURLSessionConfiguration { get }
	func invalidateAndCancel()
	func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult)	-> NSURLSessionDataTaskProtocol
	func dataTaskWithRequest(request: NSMutableURLRequestProtocol, completionHandler: DataTaskResult) -> NSURLSessionDataTaskProtocol
	func dataTaskWithRequest(request: NSMutableURLRequestProtocol) -> NSURLSessionDataTaskProtocol
}
extension NSURLSession : NSURLSessionProtocol {
	public func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult) -> NSURLSessionDataTaskProtocol {
		return dataTaskWithURL(url, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestProtocol, completionHandler: DataTaskResult) -> NSURLSessionDataTaskProtocol {
		return dataTaskWithRequest(request as! NSMutableURLRequest, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	public func dataTaskWithRequest(request: NSMutableURLRequestProtocol) -> NSURLSessionDataTaskProtocol {
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