import Foundation

protocol URLSessionTaskType {
	func isEqual(_ object: Any?) -> Bool
	var state: URLSessionTask.State { get }
}
extension URLSessionTask : URLSessionTaskType { }

// URLSessionDataTaskType
protocol URLSessionDataTaskType : URLSessionTaskType {
	func resume()
	func cancel()
	var originalRequest: URLRequest? { get }
}
extension URLSessionDataTask : URLSessionDataTaskType { }

// URLSessionType
public typealias DataTaskResult = (Data?, URLResponse?, NSError?) -> Void
protocol URLSessionType {
	var configuration: URLSessionConfiguration { get }
	func finishTasksAndInvalidate()
	func dataTaskWithRequest(_ request: URLRequest) -> URLSessionDataTaskType
}
extension URLSession : URLSessionType {
	func dataTaskWithRequest(_ request: URLRequest) -> URLSessionDataTaskType {
		return dataTask(with: request) as URLSessionDataTask
	}
}


// NSURL
public extension URL {
	init?(baseUrl: String, parameters: [String: String]? = nil) {
		var components = URLComponents(string: baseUrl)
		components?.queryItems = parameters?.map { key, value in
			URLQueryItem(name: key, value: value)
		}
		
		guard let absoluteString = components?.url?.absoluteString else { return nil }
		
		self.init(string: absoluteString)
	}
	
	internal func sha1() -> String {
		return absoluteString.lowercased().data(using: .utf8)!.sha1()
	}
}

//URLRequest
public extension URLRequest {
	init(url: URL, method: HttpMethod = .get, body: Data? = nil, headers: [String: String]) {
		self = URLRequest(url: url)
		self.httpMethod = method.rawValue
		self.httpBody = body
		headers.forEach { addValue($1, forHTTPHeaderField: $0) }
	}
	
	init?(url: URL, method: HttpMethod = .get, jsonBody: Any,
	     options: JSONSerialization.WritingOptions = [], headers: [String: String]) {
		guard JSONSerialization.isValidJSONObject(jsonBody) else { return nil }
		if let body: Data = try? JSONSerialization.data(withJSONObject: jsonBody, options: options) {
			self.init(url: url, method: method, body: body, headers: headers)
		} else {
			return nil
		}
	}
}
