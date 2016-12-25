//
//  URLRequestTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 31.10.16.
//  Copyright © 2016 RxSwift Community. All rights reserved.
//

import XCTest
@testable import RxHttpClient

class URLRequestTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testInitRequest() {
		let url = URL(string: "https://test.com")!
		let request = URLRequest(url: url)
		XCTAssertEqual(url, request.url)
		XCTAssertNil(request.allHTTPHeaderFields)
	}
	
	func testInitRequestWithHeaders() {
		let url = URL(string: "https://test.com")!
		let headers = ["header1": "value1", "header2": "value2"]
		let request = URLRequest(url: url, headers: headers)
		XCTAssertEqual(url, request.url)
		XCTAssertEqual(headers, request.allHTTPHeaderFields!)
	}
	
	func testInitWithCustomMethodAndBody() {
		let url = URL(string: "https://test.com")!
		let headers = ["header1": "value1", "header2": "value2"]
		let bodyData = "test body data".data(using: .utf8)!
		let request = URLRequest(url: url, method: .put, body: bodyData, headers: headers)
		XCTAssertEqual(url, request.url)
		XCTAssertEqual(HttpMethod.put.rawValue, request.httpMethod)
		XCTAssertTrue(request.httpBody?.elementsEqual(bodyData) ?? false)
		XCTAssertEqual(headers, request.allHTTPHeaderFields!)
	}
	
	func testInitWithJsonBody() {
		let url = URL(string: "https://test.com")!
		let headers = ["header1": "value1", "header2": "value2"]
		let bodyJson: [String: Any] = ["key1": "val1", "key2": "val2", "key3": "val3"]
		let request = try! URLRequest(url: url, method: .patch, jsonBody: bodyJson, options: [JSONSerialization.WritingOptions.prettyPrinted], headers: headers)
		XCTAssertEqual(url, request.url)
		XCTAssertEqual(HttpMethod.patch.rawValue, request.httpMethod)
		XCTAssertEqual(headers, request.allHTTPHeaderFields!)
		
		let bodyData = try! JSONSerialization.data(withJSONObject: bodyJson, options: [JSONSerialization.WritingOptions.prettyPrinted])
		XCTAssertTrue(request.httpBody?.elementsEqual(bodyData) ?? false)
		
		let deserialized = try! JSONSerialization.jsonObject(with: request.httpBody!, options: []) as! [String: String]
		XCTAssertEqual(bodyJson as! [String: String], deserialized)
	}
}
