import XCTest
@testable import RxHttpClient

class Data_ExtensionsTests: XCTestCase {
	func testSha1() {
		XCTAssertEqual("72fe95c5576ec634e214814a32ab785568eda76a", "https://google.com".data(using: .utf8)?.sha1())
		XCTAssertEqual("bbf13d251ac3cc34ea05b48313f99dd7870ea699", "https://Google.coM".data(using: .utf8)?.sha1())
		XCTAssertEqual("da39a3ee5e6b4b0d3255bfef95601890afd80709", Data().sha1())
		XCTAssertEqual("da39a3ee5e6b4b0d3255bfef95601890afd80709", "".data(using: .utf8)?.sha1())
	}
}
