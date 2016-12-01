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
	var utiType: String? { return MimeTypeConverter.mimeToUti(self.base as! String) }
	var fileExtension: String? { return MimeTypeConverter.mimeToFileExtension(self.base as! String) }
}

public extension FileExtensionType where Base : ExpressibleByStringLiteral {
	var utiType: String? { return MimeTypeConverter.fileExtensionToUti(self.base as! String) }
	var mimeType: String? { return MimeTypeConverter.fileExtensionToMime(self.base as! String) }
}

public extension UtiType where Base : ExpressibleByStringLiteral {
	var mimeType: String? { return MimeTypeConverter.utiToMime(self.base as! String) }
	var fileExtension: String? { return MimeTypeConverter.utiToFileExtension(self.base as! String) }
}
