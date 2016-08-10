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
		session = FakeSession()
		httpClient = HttpClient(session: session)
	}
	
	override func tearDown() {
		super.tearDown()
		bag = nil
		session = nil
	}
	
	func testTerminateRequest() {
		let fakeSession = FakeSession()
		let cancelExpectation = expectationWithDescription("Should cancel task")
		fakeSession.task = FakeDataTask(resumeClosure: { _ in }, cancelClosure: { cancelExpectation.fulfill() })
		let client = HttpClient(session: fakeSession)
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let disposable = client.loadData(request).observeOn(SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility))
			.doOnNext { e in
			XCTFail("Should not receive responce")
		}.subscribe()
		
		XCTAssertEqual(false, fakeSession.task?.isCancelled)
		disposable.dispose()
		waitForExpectationsWithTimeout(1, handler: nil)
		XCTAssertEqual(true, fakeSession.task!.isCancelled)
	}
	
	func testLoadCorrectData() {
		let sendData = "testData".dataUsingEncoding(NSUTF8StringEncoding)!
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = NSURL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(url).bindNext { data in
			XCTAssertEqual(true, data.isEqualToData(sendData), "Received data should be equal to sended")
			expectation.fulfill()
		}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	func testLoadCorrectEmptyData() {
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: NSData(), statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = NSURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(request).bindNext { data in
			XCTAssertEqual(true, data.isEqualToData(NSData()), "Sended data should be empty")
			expectation.fulfill()
		}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(2, handler: nil)
	}
	
	
	func testNotLoadDataIfHttpClientDisposed() {
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			XCTFail("Should not invoke HTTP request")
			return OHHTTPStubsResponse(data: NSData(), statusCode: 200, headers: nil)
		}
		
		var client: HttpClientType! = HttpClient()
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should complete observable")
		let task = client.loadData(request).doOnNext { e in
			XCTFail("Should not receive events")
			}.doOnCompleted { expectation.fulfill() }
		
		// dispose client
		client = nil
		
		//invoke task
		task.subscribe().addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
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
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let totalReceivedData = NSMutableData()
		var errorCounter = 0
		let expectation = expectationWithDescription("Should return correct data")
		client.loadData(request).observeOn(SerialDispatchQueueScheduler(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS.Utility)).doOnNext { data in
				totalReceivedData.appendData(data)
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
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return error")
		client.loadData(request).doOnError { result in
			guard case HttpClientError.ClientSideError(let error) = result else { return }
			XCTAssertEqual(error.code, 1, "Check error code")
			XCTAssertEqual(error.domain, "TestDomain", "Check error domain")
			expectation.fulfill()
			}.bindNext { _ in XCTFail("Should not emit data") }.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
	
	func testReceiveErrorResponse() {
		let sendData = "Not implemented".dataUsingEncoding(NSUTF8StringEncoding)!
		stub({ $0.URL?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 501, headers: nil)
		}
		
		let client = HttpClient()
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return error")
		client.loadData(request).doOnError { error in
			guard case let HttpClientError.InvalidResponse(response, data) = error else {
				XCTFail("Should return correct error")
				return
			}
			XCTAssertEqual(response.statusCode, 501, "Check status code of request")
			XCTAssertEqual(true, data?.isEqualToData(sendData), "Check received data equals to sended")
			expectation.fulfill()
			}.bindNext { _ in XCTFail("Should not emit data") }.addDisposableTo(bag)
		
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
		
		let request1 = (URL: NSURL(baseUrl: "https://test.com/json1", parameters: nil)!)
		let request2 = (URL: NSURL(baseUrl: "https://test.com/json2", parameters: nil)!)
		let request3 = (URL: NSURL(baseUrl: "https://test.com/json3", parameters: nil)!)
		
		let expectation1 = expectationWithDescription("Should return correct data1")
		let expectation2 = expectationWithDescription("Should return correct data2")
		let expectation3 = expectationWithDescription("Should return correct data3")
		
		let task1 = client.loadData(request1).doOnNext { data in
			XCTAssertEqual(true, data.isEqualToData(data1), "Received data should be equal to sended")
			expectation1.fulfill()
		}
		
		let task2 = client.loadData(request2).doOnNext { data in
			XCTAssertEqual(true, data.isEqualToData(data2), "Received data should be equal to sended")
			expectation2.fulfill()
		}
		
		let task3 = client.loadData(request3).doOnNext { data in
			XCTAssertEqual(true, data.isEqualToData(data3), "Received data should be equal to sended")
			expectation3.fulfill()
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
		XCTAssertEqual(false, (httpClient?.urlSession as? FakeSession)?.isFinished, "Session should be active")
		httpClient = nil
		XCTAssertEqual(true, fakeSession.isFinished, "Session should be invalidated")
	}
		
	func testCreateHttpClientWithCorrectConfiguration() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let client = HttpClient(sessionConfiguration: config)
		XCTAssertEqual(config, client.urlSession.configuration)
	}
	
	func testCreateHttpClientWithCorrectUrlSession() {
		let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
		let httpClient = HttpClient(session: session)
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
	
	func testReturnCorrectErrorIfSessionInvalidatedWithError() {
		let session = FakeSession()
		let client = HttpClient(session: session)
		
		session.task = FakeDataTask(resumeClosure: { _ in
			client.sessionObserver.sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: NSError(domain: "Test", code: 123, userInfo: nil)))
		})
		
		let request = (URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = expectationWithDescription("Should return correct error")
		client.loadData(request).doOnError { error in
			if case HttpClientError.SessionInvalidatedWithError(let error) = error where error.code == 123 {
				expectation.fulfill()
			}
		}.subscribe().addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(1, handler: nil)
	}
}