import Foundation

public protocol CacheProviderType {
	/// UID of cache provider
	var uid: String { get }
	/// Length of cached data
	var currentDataLength: Int { get }
	/// Expected length of data, that should be cached
	var expectedDataLength: Int64 { get set }
	/// MIME type of cached data
	var contentMimeType: String? { get }
	/** 
	Adds data to cache
	- parameter data: Data that would be cached
	*/
	func appendData(data: NSData)
	/**
	Gets a copy of current cached data
	- returns: Copy of data currently stored in cache
	*/
	func getCurrentData() -> NSData
	/**
	Gets a copy of current cached data within specified range
	- parameter range: The range in the cache from which to get the data. The range must not exceed the bounds of the cache.
	- returns: Copy of data currently stored in cache within range
	*/
	func getCurrentSubdata(range: NSRange) -> NSData
	/**
	Saves cached data into specified directory
	- parameter destinationDirectory: NSURL of directory, where data will be saved
	- parameter fileExtension: Extension for file (f.e. "txt" or "dat"). 
	If nil, extension will be inferred by MIME type, if inferring fails, extension will be "dat"
	- returns: NSURL for saved file or nil, if file not saved
	*/
	func saveData(destinationDirectory: NSURL, fileExtension: String?) -> NSURL?
	/**
	Sets MIME type for data if it's not nil
	- parameter mimeType: New MIME type
	*/
	func setContentMimeTypeIfEmpty(mimeType: String)
	/**
	Deletes current cached data
	*/
	func clearData()
}

public extension CacheProviderType {
	public func saveData(fileExtension: String?) -> NSURL? {
		return saveData(NSURL(fileURLWithPath: NSTemporaryDirectory()), fileExtension: fileExtension)
	}
	
	public func saveData() -> NSURL? {
		return saveData(nil)
	}
	
	public func saveData(destinationDirectory: NSURL) -> NSURL? {
		return saveData(destinationDirectory, fileExtension: nil)
	}
	
	func getCurrentSubdata(location: Int, length: Int) -> NSData {
		return getCurrentSubdata(NSMakeRange(location, length))
	}
}