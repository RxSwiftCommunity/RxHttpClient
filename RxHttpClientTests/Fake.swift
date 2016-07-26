import Foundation
@testable import RxHttpClient
import RxSwift

public enum FakeDataTaskMethods {
	case resume(FakeDataTask)
	case suspend(FakeDataTask)
	case cancel(FakeDataTask)
}

public class FakeDataTask : NSObject, NSURLSessionDataTaskType {
	@available(*, unavailable, message="completion unavailiable. Use FakeSession.sendData instead (session observer will used to send data)")
	var completion: DataTaskResult?
	let taskProgress = PublishSubject<FakeDataTaskMethods>()
	var originalRequest: NSURLRequest?
	var isCancelled = false
	var resumeInvokeCount = 0
	
	public init(completion: DataTaskResult?) {
		//self.completion = completion
	}
	
	public func resume() {
		resumeInvokeCount += 1
		taskProgress.onNext(.resume(self))
	}
	
	public func suspend() {
		taskProgress.onNext(.suspend(self))
	}
	
	public func cancel() {
		if !isCancelled {
			taskProgress.onNext(.cancel(self))
			isCancelled = true
		}
	}
}

class FakeSession : NSURLSessionType {
	var task: FakeDataTask?
	var isInvalidatedAndCanceled = false
	
	var configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
	
	init(fakeTask: FakeDataTask? = nil) {
		task = fakeTask
	}
	
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
	
	func dataTaskWithURL(url: NSURL, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		guard let task = self.task else {
			return FakeDataTask(completion: completionHandler)
		}
		//task.completion = completionHandler
		return task
	}
	
	func dataTaskWithRequest(request: NSURLRequest, completionHandler: DataTaskResult) -> NSURLSessionDataTaskType {
		fatalError("should not invoke dataTaskWithRequest with completion handler")
		guard let task = self.task else {
			return FakeDataTask(completion: completionHandler)
		}
		//task.completion = completionHandler
		task.originalRequest = request
		return task
	}
	
	func dataTaskWithRequest(request: NSURLRequest) -> NSURLSessionDataTaskType {
		guard let task = self.task else {
			return FakeDataTask(completion: nil)
		}
		task.originalRequest = request
		return task
	}
	
	func invalidateAndCancel() {
		// set flag that session was invalidated and canceled
		isInvalidatedAndCanceled = true
		
		// invoke cancelation of task
		task?.cancel()
	}
}