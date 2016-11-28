import XCTest
@testable import RxHttpClient
import OHHTTPStubs

class HttpClientCachingTests: XCTestCase {
	var cacheDirectory: URL!
	var client: HttpClient!
	
	override func setUp() {
		cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(UUID().uuidString)
		try! FileManager.default.createDirectory(atPath: cacheDirectory.path, withIntermediateDirectories: false, attributes: nil)
		client = HttpClient(urlRequestCacheProvider: UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory))
	}
	
	override func tearDown() {
		try! FileManager.default.removeItem(at: cacheDirectory)
	}
	
	func testCacheResponse() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		_ = client.requestData(url: requestUrl).subscribe(onCompleted: { exp.fulfill() })
		waitForExpectations(timeout: 0.01, handler: nil)
		
		let cachedData = try! Data(contentsOf: cacheDirectory.appendingPathComponent(requestUrl.sha1()))
		XCTAssertTrue(cachedData.elementsEqual(data), "Should cache data")
		XCTAssertEqual(1, try! FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count, "Should save data on disk")
	}
	
	func testReturnCachedResponse() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		
		try! data.write(to: cacheDirectory.appendingPathComponent(requestUrl.sha1()))
		
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		
		var returnCount = 0
		_ = client.requestData(url: requestUrl).subscribe(onNext: { _ in returnCount += 1 }, onCompleted: { exp.fulfill() })
		
		waitForExpectations(timeout: 0.01, handler: nil)
		
		XCTAssertEqual(returnCount, 2, "Should return data twice")
	}
	
	func testNotReturnNotExistedCachedResponse() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		
		var returnCount = 0
		_ = client.requestData(url: requestUrl).subscribe(onNext: { _ in returnCount += 1 }, onCompleted: { exp.fulfill() })
		
		waitForExpectations(timeout: 0.01, handler: nil)
		
		XCTAssertEqual(returnCount, 1, "Should return data only once")
	}
	
	func testNotExecuteRequest() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		
		try! data.write(to: cacheDirectory.appendingPathComponent(requestUrl.sha1()))
		
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			XCTFail("Should not invoke request")
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		
		var returnCount = 0
		_ = client.requestData(url: requestUrl, requestCacheMode: .cacheOnly).subscribe(onNext: { _ in returnCount += 1 }, onCompleted: { exp.fulfill() })
		
		waitForExpectations(timeout: 0.01, handler: nil)
		
		XCTAssertEqual(returnCount, 1, "Should return data once from cache")
	}
	
	/// Data don't exists in cache and invoking request disabled
	func testReturnNothing() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			XCTFail("Should not invoke request")
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		
		var returnCount = 0
		_ = client.requestData(url: requestUrl, requestCacheMode: .cacheOnly).subscribe(onNext: { _ in returnCount += 1 }, onCompleted: { exp.fulfill() })
		
		waitForExpectations(timeout: 0.01, handler: nil)
		
		XCTAssertEqual(returnCount, 0, "Should not return data")
	}
	
	func testNotCacheResponse() {
		let data = "Some responded data".data(using: .utf8)!
		let requestUrl = URL(string: "https://test.com/json")!
		
		let _ = stub(condition: { $0.url == requestUrl	}) { _ in
			return OHHTTPStubsResponse(data: data, statusCode: 200, headers: nil)
		}
		
		let exp = expectation(description: "Should complete request")
		
		var returnCount = 0
		_ = client.requestData(url: requestUrl, requestCacheMode: .notCacheResponse).subscribe(onNext: { _ in returnCount += 1 }, onCompleted: { exp.fulfill() })
		
		waitForExpectations(timeout: 0.01, handler: nil)
		
		XCTAssertEqual(returnCount, 1, "Should return data once from server")
		XCTAssertEqual(0, try! FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count, "Should not save data")
	}
}
