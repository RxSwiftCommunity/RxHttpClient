//
//  RequestPluginTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 28.01.17.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import XCTest
import RxHttpClient
import OHHTTPStubs

final class DummyPlugin : RequestPluginType {
	var sendCounter = 0
	var failureCounter = 0
	var successCounter = 0
	var prepareCounter = 0
	
	var newRequest: URLRequest? = nil
	
	var successData: Data? = nil
	var failureData: Data? = nil
	
	func prepare(request: URLRequest) -> URLRequest {
		prepareCounter += 1
		return newRequest ?? request
	}
	
	func beforeSend(request: URLRequest) {
		sendCounter += 1
	}
	
	func afterSuccess(response: URLResponse?, data: Data?) {
		successData = data
		successCounter += 1
	}
	
	func afterFailure(response: URLResponse?, error: Error, data: Data?) {
		failureData = data
		failureCounter += 1
	}
}

class RequestPluginTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testExecutePlugin() {
		let sendData = "some data".data(using: .utf8)!
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let completeExpectation = expectation(description: "Should complete")
		
		let plugin = DummyPlugin()
		
		let client = HttpClient(requestPlugin: CompositeRequestPlugin(plugins: plugin))
		
		_ = client.requestData(url: URL(baseUrl: "https://test.com/json")!)
			.subscribe(
				onNext: { data in
					XCTAssertTrue(sendData.elementsEqual(data))
					completeExpectation.fulfill()
			})
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(1, plugin.sendCounter)
		XCTAssertEqual(1, plugin.successCounter)
		XCTAssertEqual(0, plugin.failureCounter)
		XCTAssertEqual(1, plugin.prepareCounter)
	}
	
	func testPrepareRouting() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/routed"	&& $0.httpMethod == HttpMethod.post.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		let completeExpectation = expectation(description: "Should complete")
		
		let plugin = DummyPlugin()
		plugin.newRequest = URLRequest(url: URL(baseUrl: "https://test.com/routed")!)
		plugin.newRequest?.httpMethod = "POST"
		
		let client = HttpClient(requestPlugin: CompositeRequestPlugin(plugins: plugin))
		
		_ = client.requestData(url: URL(baseUrl: "https://test.com/json")!).subscribe(onCompleted: { completeExpectation.fulfill() })
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(1, plugin.sendCounter)
		XCTAssertEqual(1, plugin.successCounter)
		XCTAssertEqual(0, plugin.failureCounter)
		XCTAssertEqual(1, plugin.prepareCounter)
	}
	
	func testExecuteErrorPlugin() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(error: NSError(domain: "test", code: 1, userInfo: nil))
		}
		
		let completeExpectation = expectation(description: "Should complete")
		
		let plugin = DummyPlugin()
		
		let client = HttpClient(requestPlugin: CompositeRequestPlugin(plugins: plugin))
		
		_ = client.requestData(url: URL(baseUrl: "https://test.com/json")!).subscribe(onError: { _ in completeExpectation.fulfill() })
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(1, plugin.sendCounter)
		XCTAssertEqual(0, plugin.successCounter)
		XCTAssertEqual(1, plugin.failureCounter)
		XCTAssertEqual(1, plugin.prepareCounter)
	}
	
	func testExecuteErrorPluginBasedOnHttpErrorCode() {
		let errorData = "shit happens".data(using: .utf8)!
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: errorData, statusCode: 404, headers: nil)
		}
		
		let completeExpectation = expectation(description: "Should complete")
		
		let plugin = DummyPlugin()
		
		let client = HttpClient(requestPlugin: CompositeRequestPlugin(plugins: plugin))
		
		_ = client.requestData(url: URL(baseUrl: "https://test.com/json")!).subscribe(onError: { e in
			guard case let HttpClientError.invalidResponse(_, data) = e else { return }
			
			XCTAssertTrue(errorData.elementsEqual(data!))
			completeExpectation.fulfill()
		})
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(1, plugin.sendCounter)
		XCTAssertEqual(0, plugin.successCounter)
		XCTAssertEqual(1, plugin.failureCounter)
		XCTAssertEqual(1, plugin.prepareCounter)
	}
	
	
}
