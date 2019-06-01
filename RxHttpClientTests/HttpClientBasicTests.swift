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
		let resumeExpectation = expectation(description: "Should start task")
		fakeSession.task = FakeDataTask(resumeClosure: { _ in resumeExpectation.fulfill() }, cancelClosure: { _ in cancelExpectation.fulfill() })
		let client = HttpClient(session: fakeSession)
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
        
		let disposable = client.requestData(url: url)
			.do(
				onNext: { e in
				XCTFail("Should not receive responce")
			},
				onCompleted: { XCTFail("Should not complete task") })
			.subscribe()
				
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { disposable.dispose() }
		
		let waitResult = XCTWaiter().wait(for: [resumeExpectation, cancelExpectation], timeout: waitTimeout, enforceOrder: true)
		
		XCTAssertEqual(waitResult, .completed)
		XCTAssertEqual(true, fakeSession.task!.isCancelled)
	}
	
	func testLoadCorrectData() {
		let sendData = "testData".data(using: String.Encoding.utf8)!
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json" && $0.httpMethod == HttpMethod.get.rawValue	}) { _ in
			return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct data")
		client.requestData(url: url).subscribe(onNext: { data in
			XCTAssertEqual(true, data == sendData, "Received data should be equal to sended")
			expectation.fulfill()
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectEmptyData() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let request = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct data")
		client.requestData(request).subscribe(onNext: { data in
			XCTAssertEqual(true, data == Data(), "Sended data should be empty")
			expectation.fulfill()
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	
	func testNotLoadDataIfHttpClientDisposed() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
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
		task.subscribe().disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectDataAndRetryAfterError() {
		let totalSendedData = NSMutableData()
		var stubIncrement = 0
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
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
			.do(onCompleted: { expectation.fulfill() }).subscribe().disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
		
		XCTAssertEqual(5, stubIncrement)
		XCTAssertEqual(5, errorCounter)
		XCTAssertEqual(totalSendedData, totalReceivedData)
	}
	
	func testReturnErrorWhileLoadingData() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(error: NSError(domain: "TestDomain", code: 1, userInfo: nil))
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return error")
		
		client.requestData(url: url).subscribe(onNext: { _ in XCTFail("Should not emit data") }, onError: { result in
			guard case HttpClientError.clientSideError(let error) = result else { return }
			XCTAssertEqual((error as NSError).code, 1, "Check error code")
			XCTAssertEqual((error as NSError).domain, "TestDomain", "Check error domain")
			expectation.fulfill()
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testReceiveErrorResponse() {
		let sendData = "Not implemented".data(using: String.Encoding.utf8)!
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
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
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testReturnCorrectDataForMultipleRequests() {
		let data1 = "testData1".data(using: String.Encoding.utf8)!
		let data2 = "testData2".data(using: String.Encoding.utf8)!
		let data3 = "testData3".data(using: String.Encoding.utf8)!
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json1"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: data1, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json2"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: data2, statusCode: 200, headers: nil).responseTime(OHHTTPStubsDownloadSpeed1KBPS)
		}
		
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json3"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
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
		task1.subscribeOn(concurrent).subscribe().disposed(by: bag)
		task2.subscribeOn(concurrent).subscribe().disposed(by: bag)
		task3.subscribeOn(concurrent).subscribe().disposed(by: bag)
		
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
        XCTAssertNotEqual(config.httpCookieAcceptPolicy, .always)
		config.httpCookieAcceptPolicy = .always
		let client = HttpClient(sessionConfiguration: config)
        XCTAssertEqual(config.httpCookieAcceptPolicy, client.urlSession.configuration.httpCookieAcceptPolicy)
	}
	
	func testCreateHttpClientWithCorrectUrlSession() {
		let session = URLSession(configuration: URLSessionConfiguration.default)
		let httpClient = HttpClient(session: session)
		XCTAssertEqual(session, httpClient.urlSession as? URLSession)
	}
	
	func testReturnCorrectErrorIfSessionInvalidatedWithError() {
		let session = FakeSession()
		let client = HttpClient(session: session)
		
		session.task = FakeDataTask(resumeClosure: { _ in
			client.sessionDelegate.sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: NSError(domain: "Test", code: 123, userInfo: nil)))
		})
		
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct error")
		client.requestData(url: url).do(onError: { error in
			if case HttpClientError.sessionInvalidatedWithError(let error as NSError) = error , error.code == 123 {
				expectation.fulfill()
			}
		}).subscribe().disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectJson_1() {
		let sendJson: [String: Any] = ["Test": 123, "StrVal": "Some", "Dict": ["Inner": "Str"]]
		let sendJsonData = try! JSONSerialization.data(withJSONObject: sendJson, options: [])
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: sendJsonData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct json")
		client.requestJson(url: url).subscribe(onNext: { json in
			guard let json = json as? [String: Any] else { return }
			XCTAssertEqual(json["Test"] as? Int, 123)
			XCTAssertEqual(json["StrVal"] as? String, "Some")
			XCTAssertEqual((json["Dict"] as? [String: Any])?["Inner"] as? String, "Str")
			
			expectation.fulfill()
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadCorrectJson_2() {
		let sendJson: [Any] = ["testStr", 123, ["Dict": "DictVal"]]
		let sendJsonData = try! JSONSerialization.data(withJSONObject: sendJson, options: [])
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: sendJsonData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct json")
		client.requestJson(url: url).subscribe(onNext: { json in
			guard let json = json as? [Any] else { return }
			
			XCTAssertEqual(json[0] as? String, "testStr")
			XCTAssertEqual(json[1] as? Int, 123)
			XCTAssertEqual((json[2] as? [String: Any])?["Dict"] as? String, "DictVal")
			
			expectation.fulfill()
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadIncorrectJson() {
		let sendJsonData = "incorrect".data(using: .utf8)!
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: sendJsonData, statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return correct error")
		client.requestJson(url: url)
			.subscribe(
				onNext: { json in XCTFail() },
				onError: { error in
					guard case HttpClientError.jsonDeserializationError(let jsonError) = error else {
						return
					}
					XCTAssertEqual((jsonError as NSError).code, 3840)
					XCTAssertEqual((jsonError as NSError).domain, "NSCocoaErrorDomain")
					expectation.fulfill()
			}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testLoadEmptyDataJson() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
		}
		
		let client = HttpClient()
		let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should not return json")
		client.requestJson(url: url)
			.subscribe(
				onNext: { json in
			XCTFail("Should not return data")
		},
				onCompleted: { expectation.fulfill() }).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
}
