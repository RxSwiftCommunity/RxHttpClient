import Foundation
import RxSwift

public enum SessionDataEvents {
	case didReceiveResponse(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, response: NSURLResponseType,
		completion: (NSURLSessionResponseDisposition) -> Void)
	case didReceiveData(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, data: NSData)
	case didCompleteWithError(session: NSURLSessionType, dataTask: NSURLSessionTaskType, error: NSError?)
}

protocol NSURLSessionDataEventsObserverType {
	var sessionEvents: Observable<SessionDataEvents> { get }
}

extension NSURLSessionDataEventsObserver : NSURLSessionDataEventsObserverType {
	var sessionEvents: Observable<SessionDataEvents> {
		return sessionEventsSubject
	}
}

class NSURLSessionDataEventsObserver : NSObject, NSURLSessionDataDelegate {
	internal let sessionEventsSubject = PublishSubject<SessionDataEvents>()
}

extension NSURLSessionDataEventsObserver {
	func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse,
		completionHandler: (NSURLSessionResponseDisposition) -> Void) {
			sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
	}
	
	func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
		sessionEventsSubject.onNext(.didReceiveData(session: session, dataTask: dataTask, data: data))
	}
	
	func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
		sessionEventsSubject.onNext(.didCompleteWithError(session: session, dataTask: task, error: error))
	}
}