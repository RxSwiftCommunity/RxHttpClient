import XCTest
@testable import RxHttpClient

class NSURLSessionProtocolTests: XCTestCase {
	var session: NSURLSessionType = URLSession(configuration: URLSessionConfiguration.default,
	                                             delegate: nil,
	                                             delegateQueue: nil)
	var url: URL = URL(baseUrl: "https://test.com", parameters: ["param": "value"])!
	
	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
	}
	
	func testCreateDataTaskWithRequest() {
		let request = URLRequest(url: url)
		let dataTask = session.dataTaskWithRequest(URLRequest(url: url))
		XCTAssertEqual(request.url, dataTask.originalRequest?.url)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.originalRequest?.allHTTPHeaderFields?["header"])
	}
}
