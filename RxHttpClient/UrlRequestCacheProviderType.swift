import Foundation

public protocol UrlRequestCacheProviderType {
    /**
    Loads cached data for resource URL if exists
    - parameter resourceUrl: Resource for which data will be loaded
    - returns: Cached Data if exists
    */
	func load(resourceUrl url: URL) -> Data?
    /**
    Saves data for specified resource URL
    - parameter resourceUrl: Resource for which data will be stored
    - parameter data: Data to store
    */
	func save(resourceUrl url: URL, data: Data)
    /// Clears cache
	func clear()
}

public final class UrlRequestFileSystemCacheProvider {
	public let cacheDirectory: URL
	
	public init(cacheDirectory: URL) {
		self.cacheDirectory = cacheDirectory
	}
}

extension UrlRequestFileSystemCacheProvider : UrlRequestCacheProviderType {
	public func load(resourceUrl url: URL) -> Data? {
		return try? Data(contentsOf: cacheDirectory.appendingPathComponent(url.sha1()))
	}
	
	public func save(resourceUrl url: URL, data: Data) {
		_ = try? data.write(to: cacheDirectory.appendingPathComponent(url.sha1()), options: .atomic)
	}
	
	public func clear() {
		_ = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).forEach {
			_ = try? FileManager.default.removeItem(at: $0)
		}
	}
}
