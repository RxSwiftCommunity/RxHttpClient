import Foundation
import MobileCoreServices

public struct MimeTypeConverter {
	public static func mimeToUti(_ mimeType: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) else { return nil }
		
		return contentType.takeRetainedValue() as String
	}
	
	public static func utiToFileExtension(_ utiType: String) -> String? {
		guard let ext = UTTypeCopyPreferredTagWithClass(utiType as CFString, kUTTagClassFilenameExtension) else { return nil }
		
		return ext.takeRetainedValue() as String
	}
	
	public static func fileExtensionToUti(_ ext: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) else { return nil }
		return contentType.takeRetainedValue() as String
	}
	
	public static func mimeToFileExtension(_ mimeType: String) -> String? {
		guard let uti = mimeToUti(mimeType) else { return nil }
		return utiToFileExtension(uti)
	}
	
	public static func fileExtensionToMime(_ ext: String) -> String? {
		guard let uti = fileExtensionToUti(ext), let mime = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
	
	public static func utiToMime(_ uti: String) -> String? {
		guard let mime = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
}
