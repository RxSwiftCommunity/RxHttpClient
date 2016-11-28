import Foundation

public final class MemoryDataCacheProvider {
	/// Expected length of data, that should be cached
	public var expectedDataLength: Int64 = 0
	
	/// MIME type of cached data
	public internal(set) var contentMimeType: String?
	
	/// UID of cache provider
	public let uid: String
	
	/// Internal container for cached data
	internal let cacheData = NSMutableData()
	
	/// Serial queue for provide thread-safe operations
	internal let queue = DispatchQueue(label: "com.RxHttpClient.MemoryCacheProvider.SerialQueue", attributes: [])
	
	public init(uid: String = UUID().uuidString, contentMimeType: String? = nil) {
		self.uid = uid
		self.contentMimeType = contentMimeType
	}
	
	public convenience init(contentMimeType: String) {
		self.init(uid: UUID().uuidString, contentMimeType: contentMimeType)
	}
	
	/**
	Invokes provided closure synchronously in serial queue
	- parameter closure: Closure that will be invoked
	*/
	internal func invokeSerial(_ closure: () -> ()) {
		queue.sync {
			closure()
		}
	}
}

extension MemoryDataCacheProvider : DataCacheProviderType {
	/**
	Deletes current cached data
	*/
	public func clearData() {
		invokeSerial {
			guard self.cacheData.length > 0 else { return }
			self.cacheData.setData(Data())
		}
	}
	
	/**
	Sets MIME type for data if it's not nil
	- parameter mimeType: New MIME type
	*/
	public func setContentMimeTypeIfEmpty(mimeType: String) {
		invokeSerial {
			if self.contentMimeType == nil {
				self.contentMimeType = mimeType
			}
		}
	}
	
	/// Length of cached data
	public var currentDataLength: Int {
		var len: Int!
		invokeSerial {
			len = self.cacheData.length
		}
		return len
	}
	
	/**
	Adds data to cache
	- parameter data: Data that would be cached
	*/
	public func append(data: Data) {
		invokeSerial { self.cacheData.append(data) }
	}
	
	/**
	Gets a copy of current cached data
	- returns: Copy of data currently stored in cache
	*/
	public func getData() -> Data {
		var currentData: Data!
		invokeSerial {
			currentData = NSData(data: self.cacheData as Data) as Data
		}
		return currentData
	}
	
	/**
	Gets a copy of current cached data within specified range
	- parameter range: The range in the cache from which to get the data. The range must not exceed the bounds of the cache.
	- returns: Copy of data currently stored in cache within range
	*/
	public func getSubdata(range: NSRange) -> Data {
		var currentData: Data!
		invokeSerial {
			currentData = self.cacheData.subdata(with: range)
		}
		return currentData
	}
	
	/**
	Saves cached data into specified directory
	- parameter destinationDirectory: NSURL of directory, where data will be saved
	- parameter fileExtension: Extension for file (f.e. "txt" or "dat").
	If nil, extension will be inferred by MIME type, if inferring fails, extension will be "dat"
	- returns: NSURL for saved file or nil, if file not saved
	*/
	public func saveData(destinationDirectory: URL, fileExtension: String?) -> URL? {
		var resultPath: URL?
		invokeSerial {
			let fileName = "\(UUID().uuidString).\(fileExtension ?? MimeTypeConverter.getFileExtensionFromMime(self.contentMimeType ?? "") ?? "dat")"
			
			let path = destinationDirectory.appendingPathComponent(fileName)
			
			if self.cacheData.write(to: path, atomically: true) { resultPath = path }
		}
		return resultPath
	}
}
