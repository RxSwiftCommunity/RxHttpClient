import Foundation
@testable import RxHttpClient
import RxSwift

public class FakeDataTask : NSObject, NSURLSessionDataTaskType {
	var originalRequest: NSURLRequest?
	var isCancelled = false
	var resumeInvokeCount = 0
	let resumeClosure: () -> ()!
	let cancelClosure: (() -> ())?
	
	init(resumeClosure: () -> (), cancelClosure: (() -> ())? = nil) {
		self.resumeClosure = resumeClosure
		self.cancelClosure = cancelClosure
	}
	
	public func resume() {
		resumeInvokeCount += 1
		resumeClosure()
	}
	
	public func cancel() {
		if !isCancelled {
			cancelClosure?()
			isCancelled = true
		}
	}
}

class FakeSession : NSURLSessionType {
	var task: FakeDataTask!
	var isFinished = false
	
	var configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
	
	/// Send data as stream (this data should be received through session delegate)
	func sendData(task: NSURLSessionDataTaskType, data: NSData?, streamObserver: NSURLSessionDataEventsObserver) {
		if let data = data {
			streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self, dataTask: task, data: data))
		}
		// simulate delay
		NSThread.sleepForTimeInterval(0.01)
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: nil))
	}
	
	func sendError(task: NSURLSessionDataTaskType, error: NSError, streamObserver: NSURLSessionDataEventsObserver) {
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: error))
	}
	
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType {
		if task == nil { fatalError("Data task not specified") }
		task.originalRequest = request
		return task
	}
	
	func finishTasksAndInvalidate() {
		// set flag that session was invalidated
		isFinished = true
		
		// invoke cancelation of task
		task?.cancel()
	}
}