//
//  URLRequestTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 31.10.16.
//  Copyright © 2016 RxSwift Community. All rights reserved.
//

import XCTest
import RxHttpClient

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
		let request = URLRequest(url: url, headers: nil)
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
}
