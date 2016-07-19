import XCTest
@testable import RxHttpClient
import RxSwift
import OHHTTPStubs

class HttpClientBasicTests: XCTestCase {
	var bag: DisposeBag!
	var request: FakeRequest!
	var session: FakeSession!
	var utilities: FakeHttpUtilities!
	var httpClient: HttpClientType!
	var streamObserver: NSURLSessionDataEventsObserver!
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		
		bag = DisposeBag()
		streamObserver = NSURLSessionDataEventsObserver()
		request = FakeRequest()
		session = FakeSession(fakeTask: FakeDataTask(completion: nil))
		utilities = FakeHttpUtilities()
		utilities.fakeSession = session
		utilities.streamObserver = streamObserver
		httpClient = HttpClient(sessionConfiguration: NSURLSessionConfiguration.defaultSessionConfiguration(), httpUtilities: utilities)
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		bag = nil
		request = nil
		session = nil
		utilities = nil
	}
	
	func testReturnData() {
		session.task?.taskProgress.bindNext { progress in
			if case .resume(let tsk) = progress {
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
					//tsk.completion?("Test data".dataUsingEncoding(NSUTF8StringEncoding), nil, nil)
					self.session.sendData(tsk, data: "Test data".dataUsingEncoding(NSUTF8StringEncoding), streamObserver: self.streamObserver)
				}
			}
			}.addDisposableTo(bag)
		
		let expectation = expectationWithDescription("Should return string as NSData")
		
		httpClient.loadData(request).bindNext { result in
			if case .successData(let data) = result where String(data: data, encoding: NSUTF8StringEncoding) == "Test data" {
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testReturnNilData() {
		session.task?.taskProgress.bindNext { progress in
			if case .resume(let tsk) = progress {
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
					//tsk.completion?(nil, nil, nil)
					self.session.sendData(tsk, data: nil, streamObserver: self.streamObserver)
				}
			}
			}.addDisposableTo(bag)
		
		let expectation = expectationWithDescription("Should return nil (as simple Success)")
		
		httpClient.loadData(request).bindNext { result in
			if case .success = result {
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testReturnNSError() {
		session.task?.taskProgress.bindNext { progress in
			if case .resume(let tsk) = progress {
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
					//tsk.completion?(nil, nil, NSError(domain: "HttpRequestTests", code: 1, userInfo: nil))
					self.session.sendError(tsk, error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil), streamObserver: self.streamObserver)
				}
			}
			}.addDisposableTo(bag)
		
		let expectation = expectationWithDescription("Should return NSError")
		
		httpClient.loadData(request).bindNext { result in
			guard case HttpRequestResult.error(let error) = result else { return }
			if (error as NSError).code == 1 {
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testTerminateRequest() {
		let expectation = expectationWithDescription("Should cancel task")
		
		session.task?.taskProgress.bindNext { progress in
			if case .resume(let tsk) = progress {
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
					for _ in 0...10 {
						sleep(1)
					}
					//tsk.completion?(nil, nil, nil)
					self.session.sendData(tsk, data: nil, streamObserver: self.streamObserver)
				}
			} else if case .cancel(_) = progress {
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		let loadRequest = httpClient.loadData(request).bindNext { _ in
		}
		loadRequest.dispose()
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testLoadCorrectData() {
		let sendData = "testData".dataUsingEncoding(NSUTF8StringEncoding)!
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(request).bindNext { e in
			if case HttpRequestResult.successData(let data) = e {
				XCTAssertTrue(data.isEqualToData(sendData), "Received data should be equal to sended")
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testReturnErrorWhileLoadingData() {
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(error: NSError(domain: "TestDomain", code: 1, userInfo: nil))
		}
		
		let client = HttpClient()
		let request = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return error")
		client.loadData(request).bindNext { e in
			if case HttpRequestResult.error(let error as NSError) = e {
				XCTAssertEqual(error.code, 1, "Check error code")
				XCTAssertEqual(error.domain, "TestDomain", "Check error domain")
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testReturnCorrectDataForMultipleRequests() {
		let data1 = "testData1".dataUsingEncoding(NSUTF8StringEncoding)!
		let data2 = "testData2".dataUsingEncoding(NSUTF8StringEncoding)!
		let data3 = "testData3".dataUsingEncoding(NSUTF8StringEncoding)!
		
		stub({ $0.URL?.absoluteString == "https://test.com/json1"	}) { _ in
			return OHHTTPStubsResponse(data: data1, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		stub({ $0.URL?.absoluteString == "https://test.com/json2"	}) { _ in
			return OHHTTPStubsResponse(data: data2, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		stub({ $0.URL?.absoluteString == "https://test.com/json3"	}) { _ in
			return OHHTTPStubsResponse(data: data3, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let client = HttpClient()
		let bag = DisposeBag()
		
		let request1 = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json1", parameters: nil)!)
		let request2 = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json2", parameters: nil)!)
		let request3 = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json3", parameters: nil)!)
		
		let expectation1 = expectationWithDescription("Should return correct data1")
		let expectation2 = expectationWithDescription("Should return correct data2")
		let expectation3 = expectationWithDescription("Should return correct data3")
		
		let task1 = client.loadData(request1).doOnNext { e in
			if case HttpRequestResult.successData(let data) = e {
				XCTAssertTrue(data.isEqualToData(data1), "Received data should be equal to sended")
				expectation1.fulfill()
			}
		}
		
		let task2 = client.loadData(request2).doOnNext { e in
			if case HttpRequestResult.successData(let data) = e {
				XCTAssertTrue(data.isEqualToData(data2), "Received data should be equal to sended")
				expectation2.fulfill()
			}
		}
		
		let task3 = client.loadData(request3).doOnNext { e in
			if case HttpRequestResult.successData(let data) = e {
				XCTAssertTrue(data.isEqualToData(data3), "Received data should be equal to sended")
				expectation3.fulfill()
			}
		}
		
		let concurrent = ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)
		task1.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		task2.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		task3.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testDeinitOfHttpClientInvalidatesSession() {
		let utilities = FakeHttpUtilities()
		utilities.fakeSession = FakeSession()
		var httpClient: HttpClient? = HttpClient(sessionConfiguration: NSURLSessionConfiguration.defaultSessionConfiguration(), httpUtilities: utilities)
		XCTAssertEqual(false, (httpClient?.urlSession as? FakeSession)?.isInvalidatedAndCanceled, "Session should be active")
		httpClient = nil
		XCTAssertEqual(true, (utilities.fakeSession as? FakeSession)?.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testCreateHttpClientWithCorrectConfiguration() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let client = HttpClient(sessionConfiguration: config)
		XCTAssertEqual(config, client.urlSession.configuration)
	}
}