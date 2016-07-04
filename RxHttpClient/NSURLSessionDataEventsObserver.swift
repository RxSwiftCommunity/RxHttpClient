import Foundation
import RxSwift

public enum SessionDataEvents {
	case didReceiveResponse(session: NSURLSessionProtocol, dataTask: NSURLSessionDataTaskProtocol, response: NSURLResponseProtocol,
		completion: (NSURLSessionResponseDisposition) -> Void)
	case didReceiveData(session: NSURLSessionProtocol, dataTask: NSURLSessionDataTaskProtocol, data: NSData)
	case didCompleteWithError(session: NSURLSessionProtocol, dataTask: NSURLSessionTaskProtocol, error: NSError?)
}

public protocol NSURLSessionDataEventsObserverProtocol {
	var sessionEvents: Observable<SessionDataEvents> { get }
}

extension NSURLSessionDataEventsObserver : NSURLSessionDataEventsObserverProtocol {
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