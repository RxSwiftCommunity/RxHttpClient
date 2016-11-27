import Foundation

public protocol UrlRequestCacheProviderType {
	func load(resourceUrl url: URL) -> Data?
	func save(resourceUrl url: URL, data: Data)
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
