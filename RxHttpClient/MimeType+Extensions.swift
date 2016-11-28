public struct MimeType<Base> {
	public let base: Base

	public init(_ base: Base) {
		self.base = base
	}
}

public struct FileExtensionType<Base> {
	public let base: Base
	
	public init(_ base: Base) {
		self.base = base
	}
}

public struct UtiType<Base> {
	public let base: Base
	
	public init(_ base: Base) {
		self.base = base
	}
}

public extension String {
	var asMimeType: MimeType<String> { return MimeType(self) }
	var asFileExtension: FileExtensionType<String> { return FileExtensionType(self) }
	var asUtiType: UtiType<String> { return UtiType(self) }
}

public extension MimeType where Base : ExpressibleByStringLiteral {
	var utiType: String? { return MimeTypeConverter.getUtiFromMime(self.base as! String) }
	var fileExtension: String? { return MimeTypeConverter.getFileExtensionFromMime(self.base as! String) }
}

public extension FileExtensionType where Base : ExpressibleByStringLiteral {
	var utiType: String? { return MimeTypeConverter.getUtiTypeFromFileExtension(self.base as! String) }
	var mimeType: String? { return MimeTypeConverter.getMimeTypeFromFileExtension(self.base as! String) }
}

public extension UtiType where Base : ExpressibleByStringLiteral {
	var mimeType: String? { return MimeTypeConverter.getMimeTypeFromUti(self.base as! String) }
	var fileExtension: String? { return MimeTypeConverter.getFileExtensionFromUti(self.base as! String) }
}
