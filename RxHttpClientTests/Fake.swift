import Foundation
@testable import RxHttpClient
import RxSwift

open class FakeDataTask : NSObject, URLSessionDataTaskType {
	var originalRequest: URLRequest?
	var isCancelled = false
	var resumeInvokeCount = 0
	let resumeClosure: () -> ()!
	let cancelClosure: (() -> ())?
	
	var state: URLSessionTask.State = URLSessionTask.State.suspended
	
	init(resumeClosure: @escaping () -> (), cancelClosure: (() -> ())? = nil) {
		self.resumeClosure = resumeClosure
		self.cancelClosure = cancelClosure
	}
	
	open func resume() {
		resumeInvokeCount += 1
		state = .running
		resumeClosure()
	}
	
	open func cancel() {
		if !isCancelled {
			cancelClosure?()
			state = .suspended
			isCancelled = true
		}
	}
}

class FakeSession : URLSessionType {
	var task: FakeDataTask!
	var isFinished = false
	
	var state: URLSessionTask.State { return task.state }
	
	var configuration: URLSessionConfiguration = URLSessionConfiguration.default
	
	/// Send data as stream (this data should be received through session delegate)
	func sendData(_ task: URLSessionDataTaskType, data: Data?, streamObserver: NSURLSessionDataEventsObserver) {
		if let data = data {
			streamObserver.sessionEventsSubject.onNext(.didReceiveData(session: self, dataTask: task, data: data))
		}
		// simulate delay
		Thread.sleep(forTimeInterval: 0.01)
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: nil))
	}
	
	func sendError(_ task: URLSessionDataTaskType, error: NSError, streamObserver: NSURLSessionDataEventsObserver) {
		streamObserver.sessionEventsSubject.onNext(.didCompleteWithError(session: self, dataTask: task, error: error))
	}
	
	func dataTaskWithRequest(_ request: URLRequest) -> URLSessionDataTaskType {
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
