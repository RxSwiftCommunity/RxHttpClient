//
//  ActivityIndicatorPluginTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 28.01.17.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import XCTest
import OHHTTPStubs
@testable import RxHttpClient

final class DummyUIApplication : UIApplicationType {
	var isNetworkActivityIndicatorVisible: Bool = false
}

class ActivityIndicatorPluginTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testActivity() {
		let session = FakeSession()
		let activityPlugin = NetworkActivityIndicatorPlugin(applicationType: DummyUIApplication())
		let client = HttpClient(session: session, requestPlugin: activityPlugin)
		let request1 = URLRequest(url: URL(string: "https://test.com/post1")!)
		let request2 = URLRequest(url: URL(string: "https://test.com/post2")!)
		
		let fakeResponse1 = URLResponse(url: request1.url!, mimeType: nil, expectedContentLength: 64587, textEncodingName: nil)
		let fakeResponse2 = URLResponse(url: request2.url!, mimeType: nil, expectedContentLength: 64587, textEncodingName: nil)
		
		let resumeActions: (FakeDataTask) -> () = { task in
			let completion: (URLSession.ResponseDisposition) -> () = { _ in }
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
				switch task.originalRequest!.url!.absoluteString {
				case "https://test.com/post1": client.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: task, response: fakeResponse1, completion: completion))
				case "https://test.com/post2": client.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: task, response: fakeResponse2, completion: completion))
				default: break
				}
			}
		}
		
		session.customFakeTask = { req in
			let tsk = FakeDataTask(resumeClosure: resumeActions)
			tsk.originalRequest = req
			return tsk
		}
		
		let expectation1 = expectation(description: "Should return response 1")
		_ = client.request(request1).subscribe(onNext: { result in
			if case .receiveResponse = result {
				expectation1.fulfill()
			}
		})
		
		let expectation2 = expectation(description: "Should return response 2")
		_ = client.request(request2).subscribe(onNext: { result in
			if case .receiveResponse = result {
				expectation2.fulfill()
			}
		})
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertTrue(activityPlugin.application.isNetworkActivityIndicatorVisible)
		XCTAssertEqual(activityPlugin.counter, 2)
	}
	
	func testActivityInvisibleAfterSuccess() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		let activityPlugin = NetworkActivityIndicatorPlugin(applicationType: DummyUIApplication())
		let client = HttpClient(requestPlugin: activityPlugin)
		
		let completeExpectation = expectation(description: "Should complete")
		
		_ = client.requestData(URLRequest(url: URL(string: "https://test.com/json")!)).subscribe(onCompleted: { completeExpectation.fulfill() })
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertFalse(activityPlugin.application.isNetworkActivityIndicatorVisible)
		XCTAssertEqual(activityPlugin.counter, 0)
	}
	
	func testActivityInvisibleAfterError() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(error: NSError(domain: "test", code: 1, userInfo: nil))
		}
		
		let activityPlugin = NetworkActivityIndicatorPlugin(applicationType: DummyUIApplication())
		let client = HttpClient(requestPlugin: activityPlugin)
		
		let completeExpectation = expectation(description: "Should complete with error")
		
		_ = client.requestData(URLRequest(url: URL(string: "https://test.com/json")!)).subscribe(onError: { _ in completeExpectation.fulfill() })
		
		waitForExpectations(timeout: 5, handler: nil)
		
		XCTAssertFalse(activityPlugin.application.isNetworkActivityIndicatorVisible)
		XCTAssertEqual(activityPlugin.counter, 0)
	}

	/// shit tests in order to increase code coverage:)
	func testPassRealUIApplication() {
		let plugin = NetworkActivityIndicatorPlugin(application: UIApplication.shared)
		XCTAssertEqual(UIApplication.shared, plugin.application as? UIApplication)
	}
	
	func testCompositePluginSavedPassedPlugins() {
		let plugins: [RequestPluginType] = [NetworkActivityIndicatorPlugin(applicationType: DummyUIApplication()), NetworkActivityIndicatorPlugin(applicationType: DummyUIApplication())]
		let composite = CompositeRequestPlugin(plugins: plugins)
		XCTAssertEqual(2, composite.plugins.count)
	}
}
