import XCTest
import RxSwift
@testable import RxHttpClient

class StreamDataTaskTests: XCTestCase {
	var bag: DisposeBag!
	var request: NSURLRequest = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
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
		let cancelTaskExpectation = expectationWithDescription("Should cancel task")
		
		let fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		// when fake task will resumed it will invoke this closure
		let resumeActions = {
			let fakeUrlEvents = [
				SessionDataEvents.didReceiveResponse(session: self.session,
					dataTask: self.session.task,
					response: fakeResponse,
					completion: { _ in }),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "First".dataUsingEncoding(NSUTF8StringEncoding)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Second".dataUsingEncoding(NSUTF8StringEncoding)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Third".dataUsingEncoding(NSUTF8StringEncoding)!),
				SessionDataEvents.didReceiveData(session: self.session, dataTask: self.session.task, data: "Fourth".dataUsingEncoding(NSUTF8StringEncoding)!),
				SessionDataEvents.didCompleteWithError(session: self.session, dataTask: self.session.task, error: nil)
			]
			
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
				for event in fakeUrlEvents {
					// send events to session observer (simulates NSURLSession behavior)
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(event)
					// simulate delay
					NSThread.sleepForTimeInterval(0.005)
				}
			}
		}
		
		session.task = FakeDataTask(resumeClosure: resumeActions, cancelClosure: { cancelTaskExpectation.fulfill() })
		
		var receiveCounter = 0
		let dataReceived = NSMutableData()
		
		let successExpectaton = expectationWithDescription("Shoud return success event")
		
		httpClient.loadStreamData(NSURL(baseUrl: "https://test.com/json", parameters: nil)!, cacheProvider: nil).bindNext { result in
			if case .ReceiveData(let dataChunk) = result {
				dataReceived.appendData(dataChunk)
				receiveCounter += 1
			} else if case .Success(let cacheProvider) = result {
				XCTAssertNil(cacheProvider, "Cache provider should be nil")
				XCTAssertTrue(dataReceived.isEqualToData("FirstSecondThirdFourth".dataUsingEncoding(NSUTF8StringEncoding)!), "Received data should be equal to sended data")
				XCTAssertEqual(receiveCounter, 4, "Should receive correct amount of data chuncks")
				successExpectaton.fulfill()
			}
		}.addDisposableTo(bag)
		
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
	}
	
	func testReturnNSError() {
		let resumeActions = {
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
				self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: self.session.task, error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil)))
			}
		}
		session.task = FakeDataTask(resumeClosure: resumeActions)

		let expectation = expectationWithDescription("Should return NSError")
		httpClient.loadStreamData(request, cacheProvider: nil).bindNext { result in
			guard case .Error(let error) = result else { return }
			if (error as NSError).code == 1 {
				expectation.fulfill()
			}
		}.addDisposableTo(bag)

		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
	}
	
	func testDidReceiveResponse() {
		let fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: nil, expectedContentLength: 64587, textEncodingName: nil)
		let dispositionExpectation = expectationWithDescription("Should set correct completion disposition in completionHandler")
		
		let resumeActions = {
			let completion: (NSURLSessionResponseDisposition) -> () = { disposition in
				XCTAssertEqual(disposition, NSURLSessionResponseDisposition.Allow, "Check correct completion disposition in completionHandler")
				dispositionExpectation.fulfill()
			}
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
				self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: self.session.task, response: fakeResponse, completion: completion))
			}
		}
		session.task = FakeDataTask(resumeClosure: resumeActions)
		
		let expectation = expectationWithDescription("Should return correct response")
		httpClient.loadStreamData(request, cacheProvider: nil).bindNext { result in
			if case .ReceiveResponse(let response) = result {
				XCTAssertEqual(response.expectedContentLength, fakeResponse.expectedContentLength)
				XCTAssertEqual(response.URL, self.request.URL!)
				expectation.fulfill()
			}
		}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
	}
	
	func testCreateCorrectTask() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		session.task = FakeDataTask(resumeClosure: { _ in})
		let dataTask = session.dataTaskWithRequest(request)
		let streamTask = StreamDataTask(taskUid: NSUUID().UUIDString,
		                                dataTask: dataTask, httpClient: httpClient,
		                                sessionEvents: httpClient.sessionObserver.sessionEvents,
		                                cacheProvider: nil)

		XCTAssertTrue(streamTask.dataTask.originalRequest === request)
		XCTAssertNil(streamTask.cacheProvider, "Cache provider should not be specified")
	}
}
