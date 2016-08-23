import Foundation

protocol NSURLSessionTaskType {
	func isEqual(_ object: Any?) -> Bool
}
extension URLSessionTask : NSURLSessionTaskType { }

// NSURLSessionDataTaskProtocol
protocol NSURLSessionDataTaskType : NSURLSessionTaskType {
	func resume()
	func cancel()
	var originalRequest: URLRequest? { get }
}
extension URLSessionDataTask : NSURLSessionDataTaskType { }


// NSURLSessionProtocol
public typealias DataTaskResult = (Data?, URLResponse?, NSError?) -> Void
protocol NSURLSessionType {
	var configuration: URLSessionConfiguration { get }
	func finishTasksAndInvalidate()
	func dataTaskWithRequest(_ request: URLRequest) -> NSURLSessionDataTaskType
}
extension URLSession : NSURLSessionType {
	func dataTaskWithRequest(_ request: URLRequest) -> NSURLSessionDataTaskType {
		return dataTask(with: request) as URLSessionDataTask
	}
}


// NSURL
public extension URL {
	init?(baseUrl: String, parameters: [String: String]? = nil) {
		/*
		if let parameters = parameters, let components = URLComponents(string: baseUrl) {
			components.queryItems = [URLQueryItem]()
			parameters.forEach { key, value in
				components.queryItems?.append(URLQueryItem(name: key, value: value))
			}
			(self).init(string: components.url!.absoluteString)
		} else {
			(self).init(string: baseUrl)
		}
*/
		var components = URLComponents(string: baseUrl)
		components?.queryItems = parameters?.map { key, value in
			URLQueryItem(name: key, value: value)
		}
		
		guard let absoluteString = components?.url?.absoluteString else { return nil }
		
		self.init(string: absoluteString)
	}
}
