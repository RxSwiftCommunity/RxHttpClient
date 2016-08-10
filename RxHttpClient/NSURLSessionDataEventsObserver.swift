import Foundation
import RxSwift

enum SessionDataEvents {
	case didReceiveResponse(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, response: NSURLResponse,
		completion: (NSURLSessionResponseDisposition) -> Void)
	case didReceiveData(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, data: NSData)
	case didCompleteWithError(session: NSURLSessionType, dataTask: NSURLSessionTaskType, error: NSError?)
	case didBecomeInvalidWithError(session: NSURLSessionType, error: NSError?)
}

protocol NSURLSessionDataEventsObserverType {
	var sessionEvents: Observable<SessionDataEvents> { get }
}

extension NSURLSessionDataEventsObserver : NSURLSessionDataEventsObserverType {
	var sessionEvents: Observable<SessionDataEvents> {
		return sessionEventsSubject
	}
}

final class NSURLSessionDataEventsObserver : NSObject {
	internal let sessionEventsSubject = PublishSubject<SessionDataEvents>()
}

extension NSURLSessionDataEventsObserver : NSURLSessionDataDelegate {
	func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse,
	                completionHandler: (NSURLSessionResponseDisposition) -> Void) {
		sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
	}
	
	func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
		sessionEventsSubject.onNext(.didReceiveData(session: session, dataTask: dataTask, data: data))
	}
}
extension NSURLSessionDataEventsObserver : NSURLSessionDelegate {
	func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
		sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: error))
	}
}
extension NSURLSessionDataEventsObserver : NSURLSessionTaskDelegate {
	func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
		sessionEventsSubject.onNext(.didCompleteWithError(session: session, dataTask: task, error: error))
	}
}