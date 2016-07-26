import XCTest
@testable import RxHttpClient
import RxSwift
import OHHTTPStubs

class HttpClientBasicTests: XCTestCase {
	var bag: DisposeBag!
	var session: FakeSession!
	var httpClient: HttpClient!
	
	override func setUp() {
		super.setUp()
		
		bag = DisposeBag()
		session = FakeSession(fakeTask: FakeDataTask(completion: nil))
		httpClient = HttpClient(session: session)
	}
	
	override func tearDown() {
		super.tearDown()
		bag = nil
		session = nil
	}
	
	func testTerminateRequest() {
		let fakeSession = FakeSession(fakeTask: FakeDataTask(completion: nil))
		let client = HttpClient(session: fakeSession)
		let request = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let disposable = client.loadData(request).observeOn(SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility))
			.doOnNext { e in
			XCTFail("Should not receive responce")
		}.subscribe()
		
		XCTAssertEqual(false, fakeSession.task?.isCancelled)
		NSThread.sleepForTimeInterval(0.05)
		disposable.dispose()
		XCTAssertEqual(true, fakeSession.task!.isCancelled)
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
		
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	func testLoadCorrectEmptyData() {
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: NSData(), statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(request).bindNext { e in
			if case HttpRequestResult.success = e {
				expectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	func testLoadCorrectDataAndRetryAfterError() {
		let totalSendedData = NSMutableData()
		var stubIncrement = 0
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			stubIncrement += 1
			let sendData = "testData-\(stubIncrement)".dataUsingEncoding(NSUTF8StringEncoding)!
			totalSendedData.appendData(sendData)
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let totalReceivedData = NSMutableData()
		var errorCounter = 0
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(request).observeOn(SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)).doOnNext { e in
				if case HttpRequestResult.successData(let data) = e {
					totalReceivedData.appendData(data)
				}
		}
		.flatMapLatest { _ -> Observable<Void> in
			errorCounter += 1
			guard errorCounter < 5 else { return Observable<Void>.empty() }
			return Observable<Void>.error(NSError(domain: "TestDomain", code: 1, userInfo: nil))
		}
		.retryWhen { errorObservable -> Observable<Void> in
				return errorObservable.flatMapLatest { error in
					return Observable.just()
				}
			}.doOnCompleted { expectation.fulfill() }.subscribe().addDisposableTo(bag)
		
		
		waitForExpectationsWithTimeout(2, handler: nil)
		
		XCTAssertEqual(5, stubIncrement)
		XCTAssertEqual(5, errorCounter)
		XCTAssertEqual(totalSendedData, totalReceivedData)
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
		let fakeSession = FakeSession()
		var httpClient: HttpClient? = HttpClient(session: fakeSession)
		// force httpClinet to invalidete session
		httpClient?.shouldInvalidateSession = true
		XCTAssertEqual(false, (httpClient?.urlSession as? FakeSession)?.isInvalidatedAndCanceled, "Session should be active")
		httpClient = nil
		XCTAssertEqual(true, fakeSession.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testDeinitOfHttpClientNotInvalidatesPassedSession() {
		let fakeSession = FakeSession()
		var httpClient: HttpClient? = HttpClient(session: fakeSession)
		XCTAssertEqual(false, (httpClient?.urlSession as? FakeSession)?.isInvalidatedAndCanceled, "Session should be active")
		httpClient = nil
		XCTAssertEqual(false, fakeSession.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testCreateHttpClientWithCorrectConfiguration() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let client = HttpClient(sessionConfiguration: config)
		XCTAssertEqual(config, client.urlSession.configuration)
	}
	
	func testCreateHttpClientWithCorrectUrlSession() {
		let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
		let httpClient = HttpClient(urlSession: session)
		XCTAssertEqual(session, httpClient.urlSession as? NSURLSession)
	}
	
	func testCreateRequest() {
		let httpClient = HttpClient()
		let url = NSURL(string: "https://test.com")!
		let request = httpClient.createUrlRequest(url)
		XCTAssertEqual(url, request.URL)
	}
	
	func testCreateRequestWithHeaders() {
		let httpClient = HttpClient()
		let url = NSURL(string: "https://test.com")!
		let headers = ["header1": "value1", "header2": "value2"]
		let request = httpClient.createUrlRequest(url, headers: headers)
		XCTAssertEqual(url, request.URL)
		XCTAssertEqual(headers, request.allHTTPHeaderFields!)
	}
}