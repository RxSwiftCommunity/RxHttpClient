import Foundation
import RxSwift

public protocol HttpClientType : class {
	/**
	Creates streaming observable for request
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created observable that emits stream events
	*/
	func request(_ request: URLRequest, cacheProvider: CacheProviderType?) -> Observable<StreamTaskEvents>
	/**
	Creates StreamDataTask
	- parameter taskUid: String, that may be used as unique identifier of the task
	- parameter request: URL request
	- parameter cacheProvider: Cache provider, that will be used to cache downloaded data
	- returns: Created data task
	*/
	func createStreamDataTask(taskUid: String, request: URLRequest, cacheProvider: CacheProviderType?) -> StreamDataTaskType
}
