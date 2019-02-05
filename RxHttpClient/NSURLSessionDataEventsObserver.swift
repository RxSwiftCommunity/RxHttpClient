import Foundation
import RxSwift

public enum SessionDataEvents {
	case didReceiveResponse(session: URLSessionType, dataTask: URLSessionDataTaskType, response: URLResponse,
		completion: (URLSession.ResponseDisposition) -> Void)
	case didReceiveData(session: URLSessionType, dataTask: URLSessionDataTaskType, data: Data)
	case didCompleteWithError(session: URLSessionType, dataTask: URLSessionTaskType, error: Error?)
	case didBecomeInvalidWithError(session: URLSessionType, error: Error?)
}

public protocol NSURLSessionDataEventsObserverType: URLSessionDataDelegate {
	var sessionEvents: Observable<SessionDataEvents> { get }
}

open class NSURLSessionDataEventsObserver: NSObject {
	public let sessionEventsSubject = PublishSubject<SessionDataEvents>()
}

extension NSURLSessionDataEventsObserver: NSURLSessionDataEventsObserverType {
    public var sessionEvents: Observable<SessionDataEvents> {
        return sessionEventsSubject
    }
}

extension NSURLSessionDataEventsObserver: URLSessionDataDelegate {
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
	                completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
	}
	
	open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		sessionEventsSubject.onNext(.didReceiveData(session: session, dataTask: dataTask, data: data))
	}
}
extension NSURLSessionDataEventsObserver : URLSessionDelegate {
	open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		sessionEventsSubject.onNext(.didBecomeInvalidWithError(session: session, error: error))
	}
}
extension NSURLSessionDataEventsObserver : URLSessionTaskDelegate {	
	open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		sessionEventsSubject.onNext(.didCompleteWithError(session: session, dataTask: task, error: error))
	}
}
