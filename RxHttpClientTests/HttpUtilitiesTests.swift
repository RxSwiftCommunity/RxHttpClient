import XCTest
@testable import RxHttpClient

class HttpUtilitiesTests: XCTestCase {
	var request: FakeRequest!
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		request = FakeRequest(url: NSURL(baseUrl: "https://test.com", parameters: ["param": "value"]))
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		
		request = nil
	}
	
	func testCreateNSMutableURLRequest() {
		let req = HttpUtilities().createUrlRequest("https://test.com", parameters: ["param1": "value1"]) as? NSMutableURLRequest
		XCTAssertNotNil(req, "Should return instance of NSMutableURLRequest")
		XCTAssertEqual("https://test.com?param1=value1", req?.URL?.absoluteString, "Should create request with correct url")
	}
	
	func testCreateNSMutableURLRequestWithHeaders() {
		let req = HttpUtilities().createUrlRequest("https://test.com", parameters: ["param1": "value1"], headers: ["header1": "value1"]) as? NSMutableURLRequest
		XCTAssertNotNil(req, "Should return instance of NSMutableURLRequest")
		XCTAssertEqual("https://test.com?param1=value1", req?.URL?.absoluteString, "Should create request with correct url")
		XCTAssertEqual(1, req?.allHTTPHeaderFields?.count, "Should create request with one header")
		XCTAssertEqual("value1", req?.allHTTPHeaderFields!["header1"], "Should create request with correct header")
	}
	
	func testNotCreateNSMutableUrlRequestWithWrongUrl() {
		XCTAssertNil(HttpUtilities().createUrlRequest("wrong url", parameters: nil))
	}
	
	func testNotCreateNSMutableUrlRequestWithWrongUrlAndHeaders() {
		XCTAssertNil(HttpUtilities().createUrlRequest("wrong url", parameters: nil, headers: nil))
	}
	
	func testCreateUrlSession() {
		let session = HttpUtilities().createUrlSession(NSURLSession.defaultConfig) as? NSURLSession
		XCTAssertNotNil(session)
		XCTAssertEqual(session?.configuration, NSURLSession.defaultConfig)
		XCTAssertNil(session?.delegate)
	}
	
	func testCreateUrlSessionWithSpecificConfig() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let session = HttpUtilities().createUrlSession(config) as? NSURLSession
		XCTAssertEqual(session?.configuration.HTTPCookieAcceptPolicy, NSHTTPCookieAcceptPolicy.Always, "Check correct urlSession config parameter")
		XCTAssertNil(session?.delegate, "Check correct delegate")
	}
	
	func testCreateUrlSessionWithDelegate() {
		let delegate = NSURLSessionDataEventsObserver()
		let session = HttpUtilities().createUrlSession(NSURLSession.defaultConfig, delegate: delegate, queue: nil) as? NSURLSession
		XCTAssertTrue(delegate === session?.delegate, "Check correct delegate")
	}
	
	func testCreateStreamObserver() {
		XCTAssertNotNil(HttpUtilities().createUrlSessionStreamObserver())
	}
	
	func testCreateStreamDataTaskWithoutCacheProvider() {
		let utilities = HttpUtilities()
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let task = utilities.createStreamDataTask(NSUUID().UUIDString, request: request, sessionConfiguration: config, cacheProvider: nil)
		XCTAssertEqual((task as? StreamDataTask)?.request.URL?.absoluteString, request.URL?.absoluteString, "Check correct request url")
		XCTAssertTrue((task as? StreamDataTask)?.httpUtilities as? HttpUtilities === utilities, "Check correct HttpUtilities was passed")
		XCTAssertEqual((task as? StreamDataTask)?.sessionConfiguration, config, "Check correct sessionConfig was passed")
		XCTAssertNil(task.cacheProvider)
	}
	
	func testCreateStreamDataTaskWithSpecifiedCacheProvider() {
		let utilities = HttpUtilities()
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let cacheProvider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let task = utilities.createStreamDataTask(NSUUID().UUIDString, request: request, sessionConfiguration: config, cacheProvider: cacheProvider)
		XCTAssertEqual((task as? StreamDataTask)?.request.URL?.absoluteString, request.URL?.absoluteString, "Check correct request url")
		XCTAssertTrue((task as? StreamDataTask)?.httpUtilities as? HttpUtilities === utilities, "Check correct HttpUtilities was passed")
		XCTAssertEqual((task as? StreamDataTask)?.sessionConfiguration, config, "Check correct sessionConfig was passed")
		XCTAssertTrue(task.cacheProvider as? MemoryCacheProvider === cacheProvider)
	}
}