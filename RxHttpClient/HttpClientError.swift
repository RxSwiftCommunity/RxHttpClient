import Foundation

/// Represents an error
public enum HttpClientError : ErrorType {
	/**
	This error occurred if remote server returned response with unsuccessful HTTP status code (not in 2xx SUCCESS)
	- parameter response: HTTP response returned by server
	- parameter data: Data returned by server
	*/
	case InvalidResponse(response: NSHTTPURLResponse, data: NSData?)
	/**
	This error occured when underlying NSURLSession was explicitly invalidated (by finishTasksAndInvalidate() or invalidateAndCancel() methods)
	*/
	case SessionExplicitlyInvalidated
	/**
	This error occorred if underlying NSURLSession was invalidated with specific error
	- parameter error: The error that caused invalidation
	*/
	case SessionInvalidatedWithError(error: NSError)
}