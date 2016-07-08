import Foundation
import RxSwift

public enum SessionDataEvents {
	case didReceiveResponse(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, response: NSURLResponseType,
		completion: (NSURLSessionResponseDisposition) -> Void)
	case didReceiveData(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, data: NSData)
	case didCompleteWithError(session: NSURLSessionType, dataTask: NSURLSessionTaskType, error: NSError?)
}

public protocol NSURLSessionDataEventsObserverType {
	var sessionEvents: Observable<SessionDataEvents> { get }
}

extension NSURLSessionDataEventsObserver : NSURLSessionDataEventsObserverType {
	public var sessionEvents: Observable<SessionDataEvents> {
		return sessionEventsSubject
	}
}

public class NSURLSessionDataEventsObserver : NSObject, NSURLSessionDataDelegate {
	internal let sessionEventsSubject = PublishSubject<SessionDataEvents>()
}

extension NSURLSessionDataEventsObserver {
	public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse,
		completionHandler: (NSURLSessionResponseDisposition) -> Void) {
			sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
	}
	
	public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
		sessionEventsSubject.onNext(.didReceiveData(session: session, dataTask: dataTask, data: data))
	}
	
	public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
		sessionEventsSubject.onNext(.didCompleteWithError(session: session, dataTask: task, error: error))
	}
}