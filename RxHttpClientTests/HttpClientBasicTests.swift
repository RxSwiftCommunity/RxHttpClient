import XCTest
@testable import RxHttpClient
import RxSwift
import OHHTTPStubs

class HttpClientBasicTests: XCTestCase {
	var bag: DisposeBag!
	var session: FakeSession!
	var httpClient: HttpClient!
	let waitTimeout: Double = 5
	
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
		let cancelExpectation = expectation(description: "Should cancel task")
		fakeSession.task = FakeDataTask(resumeClosure: { _ in }, cancelClosure: { cancelExpectation.fulfill() })
		let client = HttpClient(session: fakeSession)
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let disposable = client.requestData(url: url).observeOn(SerialDispatchQueueScheduler(qos: .utility))
			.do(onNext: { e in
			XCTFail("Should not receive responce")
		}).subscribe()
		
		XCTAssertEqual(false, fakeSession.task?.isCancelled)
		disposable.dispose()
		waitForExpectations(timeout: waitTimeout, handler: nil)
		XCTAssertEqual(true, fakeSession.task!.isCancelled)
	}
	
	func testLoadCorrectData() {
		let sendData = "testData".data(using: String.Encoding.utf8)!
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct data")
		client.requestData(url: url).bindNext { data in
			XCTAssertEqual(true, data == sendData, "Received data should be equal to sended")
			expectation.fulfill()
		}.addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectEmptyData() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct data")
		client.requestData(request).bindNext { data in
			XCTAssertEqual(true, data == Data(), "Sended data should be empty")
			expectation.fulfill()
		}.addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	
	func testNotLoadDataIfHttpClientDisposed() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			XCTFail("Should not invoke HTTP request")
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		var client: HttpClientType! = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should complete observable")
		
		let task = client.requestData(url: url).do(onNext: { _ in XCTFail("Should not receive events") }, onCompleted: { expectation.fulfill() })
		
		// dispose client
		client = nil
		
		//invoke task
		task.subscribe().addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectDataAndRetryAfterError() {
		let totalSendedData = NSMutableData()
		var stubIncrement = 0
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			stubIncrement += 1
			let sendData = "testData-\(stubIncrement)".data(using: String.Encoding.utf8)!
			totalSendedData.append(sendData)
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let totalReceivedData = NSMutableData()
		var errorCounter = 0
		let expectation = self.expectation(description: "Should return correct data")
		
		client.requestData(url: url).observeOn(SerialDispatchQueueScheduler(qos: .utility))
			.do(onNext: { data in totalReceivedData.append(data) })
			.flatMapLatest { _ -> Observable<Void> in
				errorCounter += 1
				guard errorCounter < 5 else { return Observable<Void>.empty() }
				return Observable<Void>.error(NSError(domain: "TestDomain", code: 1, userInfo: nil))
			}
			.retryWhen { errorObservable -> Observable<Int> in
				return errorObservable.flatMapLatest { error in
					return Observable.just(1)
				}
			}
			.do(onCompleted: { expectation.fulfill() }).subscribe().addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
		
		XCTAssertEqual(5, stubIncrement)
		XCTAssertEqual(5, errorCounter)
		XCTAssertEqual(totalSendedData, totalReceivedData)
	}
	
	func testReturnErrorWhileLoadingData() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(error: NSError(domain: "TestDomain", code: 1, userInfo: nil))
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return error")
		
		client.requestData(url: url).subscribe(onNext: { _ in XCTFail("Should not emit data") }, onError: { result in
			guard case HttpClientError.clientSideError(let error) = result else { return }
			XCTAssertEqual(error.code, 1, "Check error code")
			XCTAssertEqual(error.domain, "TestDomain", "Check error domain")
			expectation.fulfill()
		}).addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testReceiveErrorResponse() {
		let sendData = "Not implemented".data(using: String.Encoding.utf8)!
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 501, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return error")
		
		client.requestData(url: url).subscribe(onNext: { _ in XCTFail("Should not emit data") }, onError: { error in
			guard case let HttpClientError.invalidResponse(response, data) = error else {
				XCTFail("Should return correct error")
				return
			}
			XCTAssertEqual(response.statusCode, 501, "Check status code of request")
			XCTAssertEqual(true, data == sendData, "Check received data equals to sended")
			expectation.fulfill()
		}).addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testReturnCorrectDataForMultipleRequests() {
		let data1 = "testData1".data(using: String.Encoding.utf8)!
		let data2 = "testData2".data(using: String.Encoding.utf8)!
		let data3 = "testData3".data(using: String.Encoding.utf8)!
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json1"	}) { _ in
			return OHHTTPStubsResponse(data: data1, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json2"	}) { _ in
			return OHHTTPStubsResponse(data: data2, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json3"	}) { _ in
			return OHHTTPStubsResponse(data: data3, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let client = HttpClient()
		let bag = DisposeBag()
		
		let url1 = URL(baseUrl: "https://test.com/json1", parameters: nil)!
		let url2 = URL(baseUrl: "https://test.com/json2", parameters: nil)!
		let url3 = URL(baseUrl: "https://test.com/json3", parameters: nil)!
		
		let expectation1 = expectation(description: "Should return correct data1")
		let expectation2 = expectation(description: "Should return correct data2")
		let expectation3 = expectation(description: "Should return correct data3")
		
		let task1 = client.requestData(url: url1).do(onNext: { data in
			XCTAssertEqual(true, data == data1, "Received data should be equal to sended")
			expectation1.fulfill()
		})
		
		let task2 = client.requestData(url: url2).do(onNext: { data in
			XCTAssertEqual(true, data == data2, "Received data should be equal to sended")
			expectation2.fulfill()
		})
		
		let task3 = client.requestData(url: url3).do(onNext: { data in
			XCTAssertEqual(true, data == data3, "Received data should be equal to sended")
			expectation3.fulfill()
		})
		
		let concurrent = ConcurrentDispatchQueueScheduler(qos: .utility)
		task1.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		task2.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		task3.subscribeOn(concurrent).subscribe().addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testDeinitOfHttpClientInvalidatesSession() {
		let fakeSession = FakeSession()
		var httpClient: HttpClient? = HttpClient(session: fakeSession)
		XCTAssertEqual(false, (httpClient?.urlSession as? FakeSession)?.isFinished, "Session should be active")
		httpClient = nil
		XCTAssertEqual(true, fakeSession.isFinished, "Session should be invalidated")
	}
		
	func testCreateHttpClientWithCorrectConfiguration() {
		let config = URLSessionConfiguration.default
		config.httpCookieAcceptPolicy = .always
		let client = HttpClient(sessionConfiguration: config)
		XCTAssertEqual(config, client.urlSession.configuration)
	}
	
	func testCreateHttpClientWithCorrectUrlSession() {
		let session = URLSession(configuration: URLSessionConfiguration.default)
		let httpClient = HttpClient(session: session)
		XCTAssertEqual(session, httpClient.urlSession as? URLSession)
	}
	
	func testCreateRequest() {
		let httpClient = HttpClient()
		let url = URL(string: "https://test.com")!
		let request = httpClient.createUrlRequest(url: url)
		XCTAssertEqual(url, request.url)
	}
	
	func testCreateRequestWithHeaders() {
		let httpClient = HttpClient()
		let url = URL(string: "https://test.com")!
		let headers = ["header1": "value1", "header2": "value2"]
		let request = httpClient.createUrlRequest(url: url, headers: headers)
		XCTAssertEqual(url, request.url)
		XCTAssertEqual(headers, request.allHTTPHeaderFields!)
	}
	
	func testReturnCorrectErrorIfSessionInvalidatedWithError() {
		let session = FakeSession()
		let client = HttpClient(session: session)
		
		session.task = FakeDataTask(resumeClosure: { _ in
			client.sessionObserver.sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: NSError(domain: "Test", code: 123, userInfo: nil)))
		})
		
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct error")
		client.requestData(url: url).do(onError: { error in
			if case HttpClientError.sessionInvalidatedWithError(let error as NSError) = error , error.code == 123 {
				expectation.fulfill()
			}
		}).subscribe().addDisposableTo(bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
}
