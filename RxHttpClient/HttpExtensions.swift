import Foundation

protocol NSURLSessionTaskType {
	func isEqual(object: AnyObject?) -> Bool
}
extension NSURLSessionTask : NSURLSessionTaskType { }

// NSURLSessionDataTaskProtocol
protocol NSURLSessionDataTaskType : NSURLSessionTaskType {
	func resume()
	func suspend()
	func cancel()
	var originalRequest: NSURLRequest? { get }
}
extension NSURLSessionDataTask : NSURLSessionDataTaskType { }


// NSURLSessionProtocol
public typealias DataTaskResult = (NSData?, NSURLResponse?, NSError?) -> Void
protocol NSURLSessionType {
	var configuration: NSURLSessionConfiguration { get }
	func invalidateAndCancel()
	func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult)	-> NSURLSessionDataTaskType
	func dataTaskWithRequest(request: NSURLRequest, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType
}
extension NSURLSession : NSURLSessionType {
	func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		return dataTaskWithURL(url, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	func dataTaskWithRequest(request: NSURLRequest, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		return dataTaskWithRequest(request, completionHandler: completionHandler) as NSURLSessionDataTask
	}
	
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType {
		return dataTaskWithRequest(request) as NSURLSessionDataTask
	}
}


// NSURL
public extension NSURL {
	convenience init?(baseUrl: String, parameters: [String: String]?) {
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
	
	func isEqualsToUrl(url: NSURL) -> Bool {
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