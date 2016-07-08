import XCTest

class NSURLTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testCreateNSURLWithParameters() {
		let url = NSURL(baseUrl: "http://test.com", parameters: ["param1": "value1", "param2": "value2"])
		XCTAssertEqual(url?.absoluteString, "http://test.com?param1=value1&param2=value2")
	}
	
	func testCreateNSURLWithEscapedParameters() {
		let url = NSURL(baseUrl: "http://test.com", parameters: ["param1": "\"#%<>\\^`{|}"])
		XCTAssertEqual(url?.absoluteString, "http://test.com?param1=%22%23%25%3C%3E%5C%5E%60%7B%7C%7D")
	}
	
	func testCreateNSURLWithoutParameters() {
		let url = NSURL(baseUrl: "http://test.com", parameters: nil)
		XCTAssertEqual(url?.absoluteString, "http://test.com")
	}
	
	func testNotCreateNSURL() {
		let url = NSURL(baseUrl: "some string", parameters: ["param1": "value1", "param2": "value2"])
		XCTAssertNil(url)
	}
}