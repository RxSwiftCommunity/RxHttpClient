import Foundation

/// Represents an error.
public enum HttpClientError : Error {
	/**
	This error occurred if remote server returned response with unsuccessful HTTP status code (not in 2xx SUCCESS).
	- parameter response: HTTP response returned by server.
	- parameter data: Data returned by server.
	*/
	case invalidResponse(response: HTTPURLResponse, data: Data?)
	/**
	This error occured when underlying NSURLSession was explicitly invalidated (by finishTasksAndInvalidate() or invalidateAndCancel() methods).
	*/
	case sessionExplicitlyInvalidated
	/**
	This error occorred if underlying NSURLSession was invalidated with specific error.
	- parameter error: The error that caused invalidation.
	*/
	case sessionInvalidatedWithError(error: Error)
	/**
	This error represents client-side error (such as being unable to resolve the hostname or connect to the host).
	*/
	case clientSideError(error: NSError)
}
