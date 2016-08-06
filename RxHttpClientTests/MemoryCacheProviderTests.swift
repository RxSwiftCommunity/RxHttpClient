import XCTest
import RxSwift
@testable import RxHttpClient

class MemoryCacheProviderTests: XCTestCase {
	var bag: DisposeBag!
	var request: NSURLRequest = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
	var session: FakeSession!
	var httpClient: HttpClient!
	let waitTimeout: Double = 2
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		
		bag = DisposeBag()
		session = FakeSession(fakeTask: FakeDataTask())
		httpClient = HttpClient(session: session)
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		bag = nil
		session = nil
	}
	
	func testCacheCorrectData() {
		let testData = ["First", "Second", "Third", "Fourth"]
		let dataSended = NSMutableData()
		let fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		
		let taskCancelExpectation = expectationWithDescription("Should cancel task and not invalidate tession")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					for i in 0...testData.count - 1 {
						let sendData = testData[i].dataUsingEncoding(NSUTF8StringEncoding)!
						dataSended.appendData(sendData)
						self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveData(session: self.session, dataTask: tsk, data: sendData))
					}
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				taskCancelExpectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		var receiveChunkCounter = 0
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).bindNext { result in
			if case StreamTaskEvents.CacheData = result {
				receiveChunkCounter += 1
			} else if case .Success(let cacheProvider) = result {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				XCTAssertEqual(testData.count, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData(dataSended), "Sended data end cached data should be equal")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = result {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
	}
	
	func testCacheCorrectDataIfDataTaskHasMoreThanOneObserver() {
		let testData = ["First", "Second", "Third", "Fourth"]
		let dataSended = NSMutableData()
		let fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					for i in 0...testData.count - 1 {
						let sendData = testData[i].dataUsingEncoding(NSUTF8StringEncoding)!
						dataSended.appendData(sendData)
						self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveData(session: self.session, dataTask: tsk, data: sendData))
						// simulate delay
						NSThread.sleepForTimeInterval(0.001)
					}
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			}
		}.addDisposableTo(bag)
		
		var receiveChunkCounter = 0
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		let dataTask = session.dataTaskWithRequest(request)
		let task = StreamDataTask(taskUid: NSUUID().UUIDString,
		                          dataTask: dataTask,
		                          httpClient: httpClient,
		                          sessionEvents: httpClient.sessionObserver.sessionEvents,
		                          cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString))

		task.taskProgress.bindNext { result in
			if case StreamTaskEvents.CacheData = result {
				receiveChunkCounter += 1
			} else if case .Success(let cacheProvider) = result {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				XCTAssertEqual(testData.count, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData(dataSended), "Sended data end cached data should be equal")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = result {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		// bind to task events one more time
		task.taskProgress.bindNext { _ in }.addDisposableTo(bag)
		
		task.resume()
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
		XCTAssertFalse(task.resumed, "Task should not be resumed")
	}
	
	func testNotOverrideMimeType() {
		let fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		
		let taskCancelExpectation = expectationWithDescription("Should cancel task and not invalidate session")
		
		session.task?.taskProgress.bindNext { [unowned self] progress in
			if case .resume(let tsk) = progress {
				XCTAssertEqual(tsk.originalRequest?.URL, self.request.URL, "Check correct task url")
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
					
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didReceiveResponse(session: self.session, dataTask: tsk, response:
						fakeResponse, completion: { _ in }))
					
					self.httpClient.sessionObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self.session, dataTask: tsk, error: nil))
				}
			} else if case .cancel = progress {
				taskCancelExpectation.fulfill()
			}
			}.addDisposableTo(bag)
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		// create memory cache provider with explicitly specified mime type
		httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString, contentMimeType: "application/octet-stream")).bindNext { result in
			if case .Success(let cacheProvider) = result {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(cacheProvider?.contentMimeType, "application/octet-stream", "Mime type should be preserved")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = result {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
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
	
	func testClearData() {
		let provider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		XCTAssertTrue(provider.currentDataLength > 0, "Should have cached data")
		provider.clearData()
		XCTAssertEqual(0, provider.currentDataLength, "Should have clean cache data")
	}
	
	func testReturnCurrentData() {
		let provider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		XCTAssertTrue(testData.isEqualToData(provider.getCurrentData()))
	}
	
	func testReturnCurrentDataOffset() {
		let provider = MemoryCacheProvider(uid: NSUUID().UUIDString)
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		//XCTAssertTrue(testData.isEqualToData(provider.getCurrentData()))
		let chunkLen = provider.currentDataLength - 2
		let chunk = provider.getCurrentSubdata(1, length: chunkLen)
		XCTAssertTrue(chunk.isEqualToData(testData.subdataWithRange(NSRange(location: 1, length: chunkLen))))
	}
	
	func testSaveDataToSpecificDir() {
		let dir = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSUUID().UUIDString)
		try! NSFileManager.defaultManager().createDirectoryAtURL(dir, withIntermediateDirectories: false, attributes: nil)
		let provider = MemoryCacheProvider(uid: "test")
		let testData = "Some test data string".dataUsingEncoding(NSUTF8StringEncoding)!
		provider.appendData(testData)
		let savedDataUrl = provider.saveData(dir)
		XCTAssertNotNil(savedDataUrl, "Should save data end return url")
		XCTAssertEqual(savedDataUrl?.pathExtension, "dat", "Should set default file extension (dat)")
		if let savedDataUrl = savedDataUrl, data = NSData(contentsOfURL: savedDataUrl) {
			XCTAssertTrue(testData.isEqualToData(data), "Saved on disk data should be same as cached data")
			try! NSFileManager.defaultManager().removeItemAtURL(dir)
		} else {
			XCTFail("Cached data should be equal to sended data")
		}
	}
}
