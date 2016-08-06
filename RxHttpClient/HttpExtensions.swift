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
	func finishTasksAndInvalidate()
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType
}
extension NSURLSession : NSURLSessionType {
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType {
		return dataTaskWithRequest(request) as NSURLSessionDataTask
	}
}


// NSURL
public extension NSURL {
	convenience init?(baseUrl: String, parameters: [String: String]? = nil) {
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
}