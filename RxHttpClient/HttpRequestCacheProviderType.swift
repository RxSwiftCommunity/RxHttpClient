import Foundation

public protocol HttpRequestCacheProviderType {
	func load(resourceUrl url: URL) -> Data?
	func save(resourceUrl url: URL, data: Data)
}

public final class HttpRequestFileSystemCacheProvider {
	public let cacheDirectory: URL
	
	public init(cacheDirectory: URL) {
		self.cacheDirectory = cacheDirectory
	}
}

extension HttpRequestFileSystemCacheProvider : HttpRequestCacheProviderType {
	public func load(resourceUrl url: URL) -> Data? {
		guard let sha1 = url.sha1() else { return nil }
		guard FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(sha1).path, isDirectory: false) else {
			return nil
		}
		
		return try? Data(contentsOf: cacheDirectory.appendingPathComponent(sha1))
	}
	
	public func save(resourceUrl url: URL, data: Data) {
		guard let sha1 = url.sha1() else { return }
		_ = try? data.write(to: cacheDirectory.appendingPathComponent(sha1), options: .atomic)
	}
}
