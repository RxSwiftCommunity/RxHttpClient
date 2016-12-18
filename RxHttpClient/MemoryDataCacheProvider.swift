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
	public func clearData() {
		invokeSerial {
			guard self.cacheData.length > 0 else { return }
			self.cacheData.setData(Data())
		}
	}
	
	public func setContentMimeTypeIfEmpty(mimeType: String) {
		invokeSerial {
			if self.contentMimeType == nil {
				self.contentMimeType = mimeType
			}
		}
	}
	
	public var currentDataLength: Int {
		var len: Int!
		invokeSerial {
			len = self.cacheData.length
		}
		return len
	}
	
	public func append(data: Data) {
		invokeSerial { self.cacheData.append(data) }
	}
	
	public func getData() -> Data {
		var currentData: Data!
		invokeSerial {
			currentData = NSData(data: self.cacheData as Data) as Data
		}
		return currentData
	}
	
	public func getSubdata(range: NSRange) -> Data {
		var currentData: Data!
		invokeSerial {
			currentData = self.cacheData.subdata(with: range)
		}
		return currentData
	}
	
	public func saveData(destinationDirectory: URL, fileExtension: String?) -> URL? {
		var resultPath: URL?
		invokeSerial {
			let fileName = "\(UUID().uuidString).\(fileExtension ?? self.contentMimeType?.asMimeType.fileExtension ?? "dat")"
			
			let path = destinationDirectory.appendingPathComponent(fileName)
			
			if self.cacheData.write(to: path, atomically: true) { resultPath = path }
		}
		return resultPath
	}
}
