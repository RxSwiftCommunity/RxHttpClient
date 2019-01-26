import XCTest
import RxSwift
import OHHTTPStubs
@testable import RxHttpClient

class StreamDataTaskTests: XCTestCase {
	var bag: DisposeBag!
	var request: URLRequest = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
	var session: FakeSession!
	var httpClient: HttpClient!
	let waitTimeout: Double = 2
	
	override func setUp() {
		super.setUp()
		
		bag = DisposeBag()
		session = FakeSession()
		httpClient = HttpClient(session: session)
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		bag = nil
		session = nil
	}
	
	func testReceiveCorrectData() {
		let cancelTaskExpectation = expectation(description: "Should cancel task")
		
		let fakeResponse = URLResponse(url: request.url!, mimeType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		// when fake task will resumed it will invoke this closure
		let resumeActions: (FakeDataTask) -> () = { _ in
			let fakeUrlEvents = [
				SessionDataEvents.didReceiveResponse(session: self.session,
					dataTask: self.session.task,
					response: fakeResponse,
					completion: { _ in }),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "First".data(using: String.Encoding.utf8)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Second".data(using: String.Encoding.utf8)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Third".data(using: String.Encoding.utf8)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Fourth".data(using: String.Encoding.utf8)!),
				SessionDataEvents.didCompleteWithError(session: self.session, dataTask: self.session.task, error: nil)
			]
			
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async { [unowned self] in
				for event in fakeUrlEvents {
					// send events to session observer (simulates NSURLSession behavior)
					self.httpClient.sessionDelegate.sessionEventsSubject.onNext(event)
					// simulate delay
					Thread.sleep(forTimeInterval: 0.005)
				}
			}
		}
		
		session.task = FakeDataTask(resumeClosure: resumeActions, cancelClosure: { _ in cancelTaskExpectation.fulfill() })
		
		var receiveCounter = 0
		let dataReceived = NSMutableData()
		
		let successExpectaton = expectation(description: "Shoud return success event")
		
		httpClient.request(url: URL(baseUrl: "https://test.com/json", parameters: nil)!, dataCacheProvider: nil).subscribe(onNext: { result in
			if case .receiveData(let dataChunk) = result {
				dataReceived.append(dataChunk)
				receiveCounter += 1
			} else if case .success(let cacheProvider) = result {
				XCTAssertNil(cacheProvider, "Cache provider should be nil")
				XCTAssertTrue(dataReceived.isEqual(to: "FirstSecondThirdFourth".data(using: String.Encoding.utf8)!), "Received data should be equal to sended data")
				XCTAssertEqual(receiveCounter, 4, "Should receive correct amount of data chuncks")
				successExpectaton.fulfill()
			}
		}).disposed(by: bag)
		
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
	}
	
	func testReturnNSError() {
		let resumeActions: (FakeDataTask) -> () = { _ in
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async { [unowned self] in
				self.httpClient.sessionDelegate.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: self.session.task, error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil)))
			}
		}
		session.task = FakeDataTask(resumeClosure: resumeActions)

		let expectation = self.expectation(description: "Should return NSError")
		httpClient.request(request, dataCacheProvider: nil).subscribe(onNext: { result in
			guard case .error(let error) = result else { return }
			if (error as NSError).code == 1 {
				expectation.fulfill()
			}
		}).disposed(by: bag)

		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testDidReceiveResponse() {
		let fakeResponse = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 64587, textEncodingName: nil)
		let dispositionExpectation = self.expectation(description: "Should set correct completion disposition in completionHandler")
		
		let resumeActions: (FakeDataTask) -> () = { _ in
			let completion: (URLSession.ResponseDisposition) -> () = { disposition in
				XCTAssertEqual(disposition, URLSession.ResponseDisposition.allow, "Check correct completion disposition in completionHandler")
				dispositionExpectation.fulfill()
			}
			DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async { [unowned self] in
				self.httpClient.sessionDelegate.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: self.session.task, response: fakeResponse, completion: completion))
			}
		}
		session.task = FakeDataTask(resumeClosure: resumeActions)
		
		let expectation = self.expectation(description: "Should return correct response")
		httpClient.request(request).subscribe(onNext: { result in
			if case .receiveResponse(let response) = result {
				XCTAssertEqual(response.expectedContentLength, fakeResponse.expectedContentLength)
				XCTAssertEqual(response.url, self.request.url!)
				expectation.fulfill()
			}
		}).disposed(by: bag)
		
		waitForExpectations(timeout: waitTimeout, handler: nil)
	}
	
	func testCreateCorrectTask() {
		let config = URLSessionConfiguration.default
		config.httpCookieAcceptPolicy = .always
		session.task = FakeDataTask(resumeClosure: { _ in})
		let dataTask = session.dataTaskWithRequest(request)
		let streamTask = StreamDataTask(taskUid: UUID().uuidString,
		                                dataTask: dataTask, 
		                                sessionEvents: httpClient.sessionObserver.sessionEvents,
		                                dataCacheProvider: nil)

		XCTAssertTrue(streamTask.dataTask.originalRequest == request)
		XCTAssertNil(streamTask.dataCacheProvider, "Cache provider should not be specified")
	}
	
	func testCheckDeinitOfHttpClientNotCancellingRunningTasks() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil).requestTime(1, responseTime: 0)
		}
		
		var client: HttpClient! = HttpClient()
		let request = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should complete stream task")
		
		// creating stream task
		let task = client.createStreamDataTask(request: request, dataCacheProvider: nil)
		task.taskProgress.subscribe(onNext: { result in
			if case StreamTaskEvents.success = result {
				expectation.fulfill()
			}
		}).disposed(by: bag)
		
		// resuming task
		task.resume()
		
		// setting cient to nil
		// client will invoke finishTasksAndInvalidate method on NSURLSession, so task should be completed
		client = nil
		waitForExpectations(timeout: 2, handler: nil)
	}
	
	func testCheckCancellingRunningTasksIfForcellyCancelSession() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil).requestTime(1, responseTime: 0)
		}
		
		let client = HttpClient()
		let request = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should return cancelation error")
		
		// creating stream task
		let task = client.createStreamDataTask(request: request, dataCacheProvider: nil)
		task.taskProgress.subscribe(onNext: { result in
			if case StreamTaskEvents.error(let error as NSError) = result , error.code == -999 {
				expectation.fulfill()
			}
			}).disposed(by: bag)
		
		// resuming task
		task.resume()
		
		// invoke invalidateAndCancel on session, this should immediatelly cancel task
		(client.urlSession as! URLSession).invalidateAndCancel()
		waitForExpectations(timeout: 2, handler: nil)
	}
	
	func testCheckTaskNotStartedIfHttpClientWasDeinited() {
		let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json"	&& $0.httpMethod == HttpMethod.get.rawValue }) { _ in
			return OHHTTPStubsResponse(data: Data(), statusCode: 200, headers: nil).requestTime(1, responseTime: 0)
		}
		
		var client: HttpClient! = HttpClient()
		let request = URLRequest(url: URL(baseUrl: "https://test.com/json", parameters: nil)!)
		let bag = DisposeBag()
		
		let expectation = self.expectation(description: "Should complete stream task")
		
		// creating stream task
		let task = client.createStreamDataTask(request: request, dataCacheProvider: nil)

		task.taskProgress.subscribe(onNext: { result in
			// checking if session was explicitly invalidated (while deinit of HttpClient)
			if case StreamTaskEvents.error(let error) = result, case HttpClientError.sessionExplicitlyInvalidated = error {
				expectation.fulfill()
			}
			}).disposed(by: bag)
		
		// setting cient to nil before resume a task
		client = nil
		
		// resuming task
		// in this case task should not be started
		task.resume()
		
		waitForExpectations(timeout: 2, handler: nil)
		XCTAssertEqual(StreamTaskState.suspended, task.state)
	}
}
