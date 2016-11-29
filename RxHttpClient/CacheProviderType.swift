import Foundation

public protocol DataCacheProviderType {
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
	func append(data: Data)
	/**
	Gets a copy of current cached data
	- returns: Copy of data currently stored in cache
	*/
	func getData() -> Data
	/**
	Gets a copy of current cached data within specified range
	- parameter range: The range in the cache from which to get the data. The range must not exceed the bounds of the cache.
	- returns: Copy of data currently stored in cache within range
	*/
	func getSubdata(range: NSRange) -> Data
	/**
	Saves cached data into specified directory
	- parameter destinationDirectory: NSURL of directory, where data will be saved
	- parameter fileExtension: Extension for file (f.e. "txt" or "dat"). 
	If nil, extension will be inferred by MIME type, if inferring fails, extension will be "dat"
	- returns: NSURL for saved file or nil, if file not saved
	*/
	func saveData(destinationDirectory: URL, fileExtension: String?) -> URL?
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

public extension DataCacheProviderType {
    /**
     Saves cached data into  Temporary Directory
     - parameter fileExtension: Extension for file (f.e. "txt" or "dat").
     If nil, extension will be inferred by MIME type, if inferring fails, extension will be "dat"
     - returns: NSURL for saved file or nil, if file not saved
     */
	public func saveData(fileExtension: String?) -> URL? {
		return saveData(destinationDirectory: URL(fileURLWithPath: NSTemporaryDirectory()), fileExtension: fileExtension)
	}

    /**
     Saves cached data into  Temporary Directory.
     Extension will be inferred by MIME type, if inferring fails, extension will be "dat"
     - returns: NSURL for saved file or nil, if file not saved
     */
	public func saveData() -> URL? {
		return saveData(fileExtension: nil)
	}
	
    /**
     Saves cached data into specified directory.
     Extension will be inferred by MIME type, if inferring fails, extension will be "dat"
     - parameter destinationDirectory: NSURL of directory, where data will be saved
     - returns: NSURL for saved file or nil, if file not saved
     */
	public func saveData(destinationDirectory: URL) -> URL? {
		return saveData(destinationDirectory: destinationDirectory, fileExtension: nil)
	}
	
    /**
     Gets a copy of current cached data within specified bounds
     - parameter location: Start position
     - parameter length: Length of data to retrieve
     - returns: Copy of data currently stored in cache within range
     */
	func getSubdata(location: Int, length: Int) -> Data {
		return getSubdata(range: NSMakeRange(location, length))
	}
}
