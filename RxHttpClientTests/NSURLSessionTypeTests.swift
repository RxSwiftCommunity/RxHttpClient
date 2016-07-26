import XCTest
@testable import RxHttpClient

class NSURLSessionProtocolTests: XCTestCase {
	var session: NSURLSessionType = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
	                                             delegate: nil,
	                                             delegateQueue: nil)
	var url: NSURL = NSURL(baseUrl: "https://test.com", parameters: ["param": "value"])!
	
	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
	}
	
	func testCreateDataTaskWithURL() {
		let dataTask = session.dataTaskWithURL(url, completionHandler: { _ in }) as? NSURLSessionDataTask
		XCTAssertEqual(url, dataTask?.originalRequest?.URL)
	}
	
	func testCreateDataTaskWithRequest() {
		let request = NSMutableURLRequest(URL: url)
		let dataTask = session.dataTaskWithRequest(NSMutableURLRequest(URL: url))
		XCTAssertEqual(request.URL, dataTask.originalRequest?.URL)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.originalRequest?.allHTTPHeaderFields?["header"])
	}
	
	func testCreateDataTaskWithRequestAndCompletionHandler() {
		let request = NSMutableURLRequest(URL: url)
		let dataTask = session.dataTaskWithRequest(request, completionHandler: { _ in })
		XCTAssertEqual(request.URL, dataTask.originalRequest?.URL)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.originalRequest?.allHTTPHeaderFields?["header"])
	}
}
