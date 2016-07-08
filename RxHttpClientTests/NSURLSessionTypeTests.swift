import XCTest
@testable import RxHttpClient

class NSURLSessionProtocolTests: XCTestCase {
	var session: NSURLSessionType!
	var url: NSURL!
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		session = NSURLSession(configuration: NSURLSession.defaultConfig,
		                       delegate: nil,
		                       delegateQueue: nil)
		url = NSURL(baseUrl: "https://test.com", parameters: ["param": "value"])
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		
		session = nil
		url = nil
	}
	
	func testCreateDataTaskWithURL() {
		let dataTask = session.dataTaskWithURL(url, completionHandler: { _ in }) as? NSURLSessionDataTask
		XCTAssertEqual(url, dataTask?.originalRequest?.URL)
	}
	
	func testCreateDataTaskWithRequest() {
		let request = HttpUtilities().createUrlRequest(url, headers: ["header": "headerValue"])
		let dataTask = session.dataTaskWithRequest(request)
		XCTAssertEqual(request.URL, dataTask.getOriginalMutableUrlRequest()?.URL)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.getOriginalMutableUrlRequest()?.allHTTPHeaderFields?["header"])
	}
	
	func testCreateDataTaskWithRequestAndCompletionHandler() {
		let request = HttpUtilities().createUrlRequest(url, headers: ["header": "headerValue"])
		let dataTask = session.dataTaskWithRequest(request, completionHandler: { _ in })
		XCTAssertEqual(request.URL, dataTask.getOriginalMutableUrlRequest()?.URL)
		XCTAssertEqual(request.allHTTPHeaderFields?["header"], dataTask.getOriginalMutableUrlRequest()?.allHTTPHeaderFields?["header"])
	}
}
