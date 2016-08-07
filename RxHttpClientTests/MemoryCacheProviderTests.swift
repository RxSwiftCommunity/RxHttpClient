import XCTest
import RxSwift
@testable import RxHttpClient

class MemoryCacheProviderTests: XCTestCase {
	var bag: DisposeBag!
	var request: NSURLRequest = NSMutableURLRequest(URL: NSURL(baseUrl: "https://test.com/json", parameters: nil)!)
	var session: FakeSession!
	var httpClient: HttpClient!
	let waitTimeout: Double = 2
	var fakeResponse: NSURLResponse!
	var resumeActions: (() -> ())!
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		
		bag = DisposeBag()
		//session = FakeSession(fakeTask: FakeDataTask())
		session = FakeSession()
		httpClient = HttpClient(session: session)
		
		fakeResponse = NSURLResponse(URL: request.URL!, MIMEType: "audio/mpeg", expectedContentLength: 26, textEncodingName: nil)
		// when fake task will resumed it will invoke this closure
		resumeActions = {
			let fakeUrlEvents = [
				SessionDataEvents.didReceiveResponse(session: self.session,
					dataTask: self.session.task,
					response: self.fakeResponse,
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
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		bag = nil
		session = nil
	}
	
	func testCacheCorrectData() {
		let taskCancelExpectation = expectationWithDescription("Should cancel task and not invalidate tession")
		session.task = FakeDataTask(resumeClosure: resumeActions, cancelClosure: { taskCancelExpectation.fulfill() })

		var receiveChunkCounter = 0
		
		let successExpectation = expectationWithDescription("Should successfuly cache data")
		
		httpClient.loadStreamData(request, cacheProvider: MemoryCacheProvider(uid: NSUUID().UUIDString)).bindNext { result in
			if case StreamTaskEvents.CacheData = result {
				receiveChunkCounter += 1
			} else if case .Success(let cacheProvider) = result {
				XCTAssertNotNil(cacheProvider, "Cache provider should be specified")
				XCTAssertEqual(self.fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(self.fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				XCTAssertEqual(4, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData("FirstSecondThirdFourth".dataUsingEncoding(NSUTF8StringEncoding)!), "Sended data end cached data should be equal")
				successExpectation.fulfill()
			} else if case StreamTaskEvents.ReceiveData = result {
				XCTFail("Shouldn't rise this event because CacheProvider was specified")
			}
			}.addDisposableTo(bag)
		
		waitForExpectationsWithTimeout(waitTimeout, handler: nil)
		XCTAssertFalse(self.session.isFinished, "Session should not be invalidated")
	}
	
	func testCacheCorrectDataIfDataTaskHasMoreThanOneObserver() {
		session.task = FakeDataTask(resumeClosure: resumeActions)

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
				XCTAssertEqual(self.fakeResponse.expectedContentLength, cacheProvider?.expectedDataLength, "Should have expectedDataLength same as length in response")
				XCTAssertEqual(self.fakeResponse.MIMEType, cacheProvider?.contentMimeType, "Should have mime type same as mime type of request")
				XCTAssertEqual(4, receiveChunkCounter, "Should cache correct data chunk amount")
				XCTAssertEqual(true, cacheProvider?.getCurrentData().isEqualToData("FirstSecondThirdFourth".dataUsingEncoding(NSUTF8StringEncoding)!), "Sended data end cached data should be equal")
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
		let taskCancelExpectation = expectationWithDescription("Should cancel task and not invalidate session")
		session.task = FakeDataTask(resumeClosure: resumeActions, cancelClosure: { taskCancelExpectation.fulfill() })
		
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
