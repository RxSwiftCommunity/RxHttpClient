import Foundation
import RxSwift

enum SessionDataEvents {
	case didReceiveResponse(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, response: URLResponse,
		completion: (URLSession.ResponseDisposition) -> Void)
	case didReceiveData(session: NSURLSessionType, dataTask: NSURLSessionDataTaskType, data: Data)
	case didCompleteWithError(session: NSURLSessionType, dataTask: NSURLSessionTaskType, error: Error?)
	case didBecomeInvalidWithError(session: NSURLSessionType, error: Error?)
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

extension NSURLSessionDataEventsObserver : URLSessionDataDelegate {
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
	                completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		sessionEventsSubject.onNext(.didReceiveData(session: session, dataTask: dataTask, data: data))
	}
}
extension NSURLSessionDataEventsObserver : URLSessionDelegate {
	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: error))
	}
}
extension NSURLSessionDataEventsObserver : URLSessionTaskDelegate {	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		sessionEventsSubject.onNext(.didCompleteWithError(session: session, dataTask: task, error: error))
	}
}
