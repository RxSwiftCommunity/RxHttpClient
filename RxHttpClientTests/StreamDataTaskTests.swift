import XCTest
import RxSwift
@testable import RxHttpClient

class StreamDataTaskTests: XCTestCase {
	var bag: DisposeBag!
	var request: FakeRequest!
	var session: FakeSession!
	var utilities: FakeHttpUtilities!
	var httpClient: HttpClient!
	var streamObserver: NSURLSessionDataEventsObserver!
	let waitTimeout: Double = 2
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		
		bag = DisposeBag()
		streamObserver = NSURLSessionDataEventsObserver()
		request = FakeRequest(url: NSURL(string: "https://test.com"))
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
		utilities.streamObserver = nil
		utilities = nil
		streamObserver = nil
	}
	
	func testReceiveCorrectData() {
		let testData = ["First", "Second", "Third", "Fourth"]
		let dataSended = NSMutableData()
		
		let expectation = expectationWithDescription("Should return correct data and not invalidate session")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					for i in 0...testData.count - 1 {
						let sendData = testData[i].dataUsingEncoding(NSUTF8StringEncoding)!
						//dataSended += UInt64(sendData.length)
						dataSended.appendData(sendData)
						self.streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self.session, dataTask: tsk, data: sendData))
						// simulate delay
						NSThread.sleepForTimeInterval(0.01)
					}
					self.streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				// set reference to nil (simutale real session dispose)
				self.utilities.streamObserver = nil
				self.streamObserver = nil
				expectation.fulfill()
			}
		}.addDisposableTo(bag)
		
		var receiveCounter = 0
		let dataReceived = NSMutableData()
		httpClient.loadStreamData(request, cacheProvider: nil).bindNext { result in
			if case .receiveData(let dataChunk) = result {
				XCTAssertEqual(String(data: dataChunk, encoding: NSUTF8StringEncoding), testData[receiveCounter], "Check correct chunk of data received")
				dataReceived.appendData(dataChunk)
				receiveCounter += 1
			} else if case .success(let cacheProvider) = result {
				XCTAssertNil(cacheProvider, "Cache provider should be nil")
				XCTAssertTrue(dataReceived.isEqualToData(dataSended), "Received data should be equal to sended data")
				XCTAssertEqual(receiveCounter, testData.count, "Should receive correct amount of data chuncks")
			}
		}.addDisposableTo(bag)
		
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isInvalidatedAndCanceled, "Session should not be invalidated")
	}
	
	func testReturnNSError() {
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					self.streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: NSError(domain: "HttpRequestTests", code: 1, userInfo: nil)))
				}
			}
		}.addDisposableTo(bag)

		let expectation = expectationWithDescription("Should return NSError")
		httpClient.loadStreamData(request, cacheProvider: nil).bindNext { result in
			guard case .error(let error) = result else { return }
			if (error as NSError).code == 1 {
				expectation.fulfill()
			}
		}.addDisposableTo(bag)

		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
	}
	
	func testDidReceiveResponse() {
		var disposition: NSURLSessionResponseDisposition?
		let fakeResponse = FakeResponse(contentLenght: 64587)
		let dispositionExpectation = expectationWithDescription("Should set correct completion disposition in completionHandler")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				let completion: (NSURLSessionResponseDisposition) -> () = { disp in
					disposition = disp
					dispositionExpectation.fulfill()
				}
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					self.streamObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response: fakeResponse, completion: completion))
				}
			}
			}.addDisposableTo(bag)
		
		let expectation = expectationWithDescription("Should return correct response")
		httpClient.loadStreamData(request, cacheProvider: nil).bindNext { result in
			if case .receiveResponse(let response) = result {
				XCTAssertEqual(response.expectedContentLength, fakeResponse.expectedContentLength)
				expectation.fulfill()
			}
		}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertEqual(disposition, NSURLSessionResponseDisposition.Allow, "Check correct completion disposition in completionHandler")
	}
	
	func testCreateCorrectTask() {
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		config.HTTPCookieAcceptPolicy = .Always
		let dataTask = session.dataTaskWithRequest(request)
		let streamTask = StreamDataTask(taskUid: NSUUID().UUIDString,
		                                dataTask: dataTask, httpClient: httpClient,
		                                sessionEvents: httpClient.sessionObserver.sessionEvents,
		                                cacheProvider: nil)

		XCTAssertTrue(streamTask.dataTask.getOriginalUrlRequest() as? FakeRequest === request)
		XCTAssertNil(streamTask.cacheProvider, "Cache provider should not be specified")
	}
}
