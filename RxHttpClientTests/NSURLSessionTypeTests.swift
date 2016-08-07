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
	
	func testCreateDataTaskWithRequest() {
		let request = NSMutableURLRequest(URL: url)
		let dataTask = session.dataTaskWithRequest(NSMutableURLRequest(URL: url))
		XCTAssertEqual(request.URL, dataTask.originalRequest?.URL)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.originalRequest?.allHTTPHeaderFields?["header"])
	}
}
