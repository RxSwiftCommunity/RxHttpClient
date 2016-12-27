//
//  HttpClientSendTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 26.12.16.
//  Copyright © 2016 RxSwiftCommunity. All rights reserved.
//

import XCTest
@testable import RxHttpClient
import OHHTTPStubs

class HttpClientSendTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testSendBody() {
		let session = FakeSession()
		let client = HttpClient(session: session)
		let sendData = "testData".data(using: String.Encoding.utf8)!
		
		let actions: (FakeDataTask) -> () = { task in
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async { _ in
				guard task.originalRequest!.url! == URL(baseUrl: "https://test.com/post", parameters: ["post":"Request"])!,
					task.originalRequest!.httpMethod == HttpMethod.post.rawValue,
					task.originalRequest!.allHTTPHeaderFields?["Header1"] == "HeaderVal1",
					task.originalRequest!.httpBody?.elementsEqual(sendData) ?? false else {
						
						client.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: session,
						                                                                         dataTask: task,
						                                                                         error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil)))
						
						return
				}
				
				client.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: session,
				                                                                         dataTask: task,
				                                                                         error: nil))
			}
		}
		
		session.task = FakeDataTask(resumeClosure: actions)
		
		let url = URL(baseUrl: "https://test.com/post", parameters: ["post":"Request"])!
		let expectation = self.expectation(description: "Should receive OK response")
		
		_ = client.requestData(url: url, method: .post, body: sendData, httpHeaders: ["Header1": "HeaderVal1"], requestCacheMode: CacheMode.withoutCache)
			.subscribe(onNext: { _ in expectation.fulfill() }, onError: { _ in XCTFail("error returned") })
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testSendJsonBody() {
		let session = FakeSession()
		let client = HttpClient(session: session)
		let sendJson = ["Key1":"Value1", "Key2":"Value2"]
		
		let sendJsonData = try! JSONSerialization.data(withJSONObject: sendJson, options: [])
		
		let actions: (FakeDataTask) -> () = { task in
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async { _ in
				guard task.originalRequest!.url! == URL(baseUrl: "https://test.com/post", parameters: ["post":"Request"])!,
					task.originalRequest!.httpMethod == HttpMethod.patch.rawValue,
					task.originalRequest!.allHTTPHeaderFields?["Header1"] == "HeaderVal1",
					task.originalRequest!.httpBody?.elementsEqual(sendJsonData) ?? false else {
						
						client.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: session,
						                                                                         dataTask: task,
						                                                                         error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil)))
						
						return
				}
				
				client.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: session,
				                                                                         dataTask: task,
				                                                                         error: nil))
			}
		}
		
		session.task = FakeDataTask(resumeClosure: actions)
		
		let url = URL(baseUrl: "https://test.com/post", parameters: ["post":"Request"])!
		let expectation = self.expectation(description: "Should receive OK response")
		
		_ = client.requestData(url: url, method: .patch, jsonBody: sendJson, options: [], httpHeaders: ["Header1": "HeaderVal1"], requestCacheMode: CacheMode.withoutCache)
			.subscribe(onNext: { _ in expectation.fulfill() }, onError: { _ in XCTFail("error returned") })
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testRequestWithIncorrectJsonObject() {
		let url = URL(baseUrl: "https://test.com/post", parameters: ["post":"Request"])!
		let expectation = self.expectation(description: "Should receive error")
		
		let client = HttpClient()
		_ = client.requestData(url: url, method: .patch, jsonBody: 2, options: [], httpHeaders: ["Header1": "HeaderVal1"], requestCacheMode: CacheMode.withoutCache)
			.subscribe(onNext: { _ in XCTFail("Should not return data") }, onError: { error in
				guard case HttpClientError.invalidJsonObject = error else { XCTFail("Incorrect error returned"); return }
				expectation.fulfill()
			})
		
		waitForExpectations(timeout: 1, handler: nil)
	}
}
