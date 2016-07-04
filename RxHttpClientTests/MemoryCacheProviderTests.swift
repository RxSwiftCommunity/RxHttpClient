import XCTest
import RxSwift
@testable import RxHttpClient

class MemoryCacheProviderTests: XCTestCase {
	var bag: DisposeBag!
	var request: FakeRequest!
	var session: FakeSession!
	var utilities: FakeHttpUtilities!
	var httpClient: HttpClientProtocol!
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
		httpClient = HttpClient(httpUtilities: utilities)
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
	
	func testCacheCorrectData() {
		let testData = ["First", "Second", "Third", "Fourth"]
		let dataSended = NSMutableData()
		let fakeResponse = FakeResponse(contentLenght: Int64(26))
		fakeResponse.MIMEType = "audio/mpeg"
		
		let sessionInvalidationExpectation = expectationWithDescription("Should return correct data and invalidate session")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.streamObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					for i in 0...testData.count - 1 {
						let sendData = testData[i].dataUsingEncoding(NSUTF8StringEncoding)!
						dataSended.appendData(sendData)
						self.streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self.session, dataTask: tsk, data: sendData))
						// simulate delay
						//NSThread.sleepForTimeInterval(0.01)
					}
					self.streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				// task will be canceled if method cancelAndInvalidate invoked on FakeSession,
				// so fulfill expectation here after checking if session was invalidated
				if self.session.isInvalidatedAndCanceled {
					sessionInvalidationExpectation.fulfill()
				}
			}
			}.addDisposableTo(bag)
		
		var receiveChunkCounter = 0
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).bindNext { result in
			guard case Result.success(let box) = result else { return }
			if case StreamTaskEvents.CacheData = box.value {
				receiveChunkCounter += 1
			} else if case .Success(let cacheProvider) = box.value {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				//XCTAssertEqual(cacheProvider?.getData().length, dataSended, "Should cache all sended data")
				XCTAssertEqual(testData.count, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData(dataSended), "Sended data end cached data should be equal")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = box.value {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertTrue(self.session.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testCacheCorrectDataIfDataTaskHasMoreThanOneObserver() {
		let testData = ["First", "Second", "Third", "Fourth"]
		let dataSended = NSMutableData()
		let fakeResponse = FakeResponse(contentLenght: Int64(26))
		fakeResponse.MIMEType = "audio/mpeg"
		
		let sessionInvalidationExpectation = expectationWithDescription("Should return correct data and invalidate session")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.streamObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					for i in 0...testData.count - 1 {
						let sendData = testData[i].dataUsingEncoding(NSUTF8StringEncoding)!
						dataSended.appendData(sendData)
						self.streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self.session, dataTask: tsk, data: sendData))
						// simulate delay
						NSThread.sleepForTimeInterval(0.01)
					}
					self.streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				// task will be canceled if method cancelAndInvalidate invoked on FakeSession,
				// so fulfill expectation here after checking if session was invalidated
				if self.session.isInvalidatedAndCanceled {
					// set reference to nil (simutale real session dispose)
					self.utilities.streamObserver = nil
					self.streamObserver = nil
					sessionInvalidationExpectation.fulfill()
				}
			}
			}.addDisposableTo(bag)
		
		var receiveChunkCounter = 0
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		let task = StreamDataTask(taskUid: NSUUID().UUIDString, request: request, httpUtilities: utilities,
		                          sessionConfiguration: NSURLSession.defaultConfig, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString))
		//httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).bindNext { result in
		task.taskProgress.bindNext { result in
			guard case Result.success(let box) = result else { return }
			if case StreamTaskEvents.CacheData = box.value {
				receiveChunkCounter += 1
			} else if case .Success(let cacheProvider) = box.value {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				//XCTAssertEqual(cacheProvider?.getData().length, dataSended, "Should cache all sended data")
				XCTAssertEqual(testData.count, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData(dataSended), "Sended data end cached data should be equal")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = box.value {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		// bind to task events one more time
		task.taskProgress.bindNext { _ in }.addDisposableTo(bag)
		
		task.resume()
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertTrue(self.session.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testNotOverrideMimeType() {
		let fakeResponse = FakeResponse(contentLenght: Int64(26))
		fakeResponse.MIMEType = "audio/mpeg"
		
		let sessionInvalidationExpectation = expectationWithDescription("Should return correct data and invalidate session")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.streamObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					self.streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				// task will be canceled if method cancelAndInvalidate invoked on FakeSession,
				// so fulfill expectation here after checking if session was invalidated
				if self.session.isInvalidatedAndCanceled {
					// set reference to nil (simutale real session dispose)
					self.utilities.streamObserver = nil
					self.streamObserver = nil
					sessionInvalidationExpectation.fulfill()
				}
			}
			}.addDisposableTo(bag)
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		// create memory cache provider with explicitly specified mime type
		httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString, contentMimeType: "application/octet-stream")).bindNext { result in
			guard case Result.success(let box) = result else { return }
			if case .Success(let cacheProvider) = box.value {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(cacheProvider?.contentMimeType, "application/octet-stream", "Mime type should be preserved")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = box.value {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertTrue(self.session.isInvalidatedAndCanceled, "Session should be invalidated")
	}
	
	func testSaveDataOnDisk() {
		let provider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		XCTAssertTrue(testData.isEqualToData(provider.getCurrentData()), "Cached data should be equal to data sended in cache")
		let savedDataUrl = provider.saveData()
		XCTAssertNotNil(savedDataUrl, "Should save data end return url")
		XCTAssertEqual(savedDataUrl?.pathExtension, "dat", "Should set default file extension (dat)")
		if let savedDataUrl = savedDataUrl, data = NSData(contentsOfURL: savedDataUrl) {
			XCTAssertTrue(testData.isEqualToData(data), "Saved on disk data should be same as cached data")
			try! NSFileManager.defaultManager().removeItemAtURL(savedDataUrl)
		} else {
			XCTFail("Cached data should be equal to sended data")
		}
	}
	
	func testSaveDataOnDiskWithCustomExtension() {
		let provider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		let savedDataUrl = provider.saveData("mp3")
		XCTAssertEqual(savedDataUrl?.pathExtension, "mp3", "Should set specified file extension")
		if let savedDataUrl = savedDataUrl {
			try! NSFileManager.defaultManager().removeItemAtURL(savedDataUrl)
		}
	}
}
