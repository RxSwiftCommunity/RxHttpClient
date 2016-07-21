import Foundation

public protocol CacheProviderType {
	var uid: String { get }
	var currentDataLength: UInt64 { get }
	var expectedDataLength: Int64 { get set }
	var contentMimeType: String? { get }
	func appendData(data: NSData)
	func getCurrentData() -> NSData
	func getCurrentData(offset: Int, length: Int) -> NSData
	func saveData() -> NSURL?
	func saveData(fileExtension: String?) -> NSURL?
	func saveData(destinationDirectory: NSURL, fileExtension: String?) -> NSURL?
	func saveData(destinationDirectory: NSURL) -> NSURL?
	func setContentMimeTypeIfEmpty(mimeType: String)
	func clearData()
}

public class MemoryCacheProvider {
	public var expectedDataLength: Int64 = 0
	internal let cacheData = NSMutableData()
	public var contentMimeType: String?
	public let uid: String
	
	internal let queue = dispatch_queue_create("com.cloudmusicplayer.memorycacheprovider.serialqueue.\(NSUUID().UUIDString)", DISPATCH_QUEUE_SERIAL)
	
	public init(uid: String, contentMimeType: String? = nil) {
		self.uid = uid
		self.contentMimeType = contentMimeType
	}
	
	internal func invokeSerial(clousure: () -> ()) {
		dispatch_sync(queue) {
			clousure()
		}
	}
}

extension MemoryCacheProvider : CacheProviderType {
	public func clearData() {
		invokeSerial {
			guard self.cacheData.length > 0 else { return }
			self.cacheData.setData(NSData())
		}
	}
	
	/// Set content MIME type. 
	///Only if now contentMimeType property is nil
	public func setContentMimeTypeIfEmpty(mimeType: String) {
		invokeSerial {
			if self.contentMimeType == nil {
				self.contentMimeType = mimeType
			}
		}
	}
	
	public var currentDataLength: UInt64 {
		var len: UInt64!
		invokeSerial {
			len = UInt64(self.cacheData.length)
		}
		return len
	}
	
	public func appendData(data: NSData) {
		invokeSerial { self.cacheData.appendData(data) }
	}
	
	public func getCurrentData() -> NSData {
		var currentData: NSData!
		invokeSerial {
			currentData = NSData(data: self.cacheData)
		}
		return currentData
	}
	
	public func getCurrentData(offset: Int, length: Int) -> NSData {
		var currentData: NSData!
		invokeSerial {
			currentData = self.cacheData.subdataWithRange(NSMakeRange(Int(offset), Int(length)))
		}
		return currentData
	}
	
	public func saveData(fileExtension: String?) -> NSURL? {
		return saveData(NSURL(fileURLWithPath: NSTemporaryDirectory()), fileExtension: fileExtension)
	}
	
	public func saveData() -> NSURL? {
		return saveData(nil)
	}
	
	public func saveData(destinationDirectory: NSURL) -> NSURL? {
		return saveData(destinationDirectory, fileExtension: nil)
	}
	
	public func saveData(destinationDirectory: NSURL, fileExtension: String?) -> NSURL? {
		var resultPath: NSURL?
		invokeSerial {
			let fileName = "\(NSUUID().UUIDString).\(fileExtension ?? MimeTypeConverter.getFileExtensionFromMime(self.contentMimeType ?? "") ?? "dat")"
			
			let path = destinationDirectory.URLByAppendingPathComponent(fileName)
			
			if self.cacheData.writeToURL(path, atomically: true) { resultPath = path }
		}
		return resultPath
	}
}