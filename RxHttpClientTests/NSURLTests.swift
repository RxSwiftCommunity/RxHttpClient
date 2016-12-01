import XCTest
@testable import RxHttpClient

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
		let url = URL(baseUrl: "http://test.com", parameters: ["param1": "value1", "param2": "value2"])
		XCTAssertEqual(url?.absoluteString, "http://test.com?param1=value1&param2=value2")
	}
	
	func testCreateNSURLWithEscapedParameters() {
		let url = URL(baseUrl: "http://test.com", parameters: ["param1": "\"#%<>\\^`{|}"])
		XCTAssertEqual(url?.absoluteString, "http://test.com?param1=%22%23%25%3C%3E%5C%5E%60%7B%7C%7D")
	}
	
	func testCreateNSURLWithoutParameters() {
		let url = URL(baseUrl: "http://test.com", parameters: nil)
		XCTAssertEqual(url?.absoluteString, "http://test.com")
	}
	
	func testNotCreateNSURL() {
		let url = URL(baseUrl: "some string", parameters: ["param1": "value1", "param2": "value2"])
		XCTAssertNil(url)
	}
	
	func testSha1() {
		XCTAssertEqual("72fe95c5576ec634e214814a32ab785568eda76a", URL(baseUrl: "https://google.com")?.sha1())
		XCTAssertEqual("72fe95c5576ec634e214814a32ab785568eda76a", URL(baseUrl: "https://Google.coM")?.sha1())
	}
}
