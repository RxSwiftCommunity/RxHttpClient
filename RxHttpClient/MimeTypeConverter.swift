import Foundation
import MobileCoreServices

public struct MimeTypeConverter {
	public static func getUtiFromMime(_ mimeType: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) else { return nil }
		
		return contentType.takeRetainedValue() as String
	}
	
	public static func getFileExtensionFromUti(_ utiType: String) -> String? {
		guard let ext = UTTypeCopyPreferredTagWithClass(utiType as CFString, kUTTagClassFilenameExtension) else { return nil }
		
		return ext.takeRetainedValue() as String
	}
	
	public static func getUtiTypeFromFileExtension(_ ext: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) else { return nil }
		return contentType.takeRetainedValue() as String
	}
	
	public static func getFileExtensionFromMime(_ mimeType: String) -> String? {
		guard let uti = getUtiFromMime(mimeType) else { return nil }
		return getFileExtensionFromUti(uti)
	}
	
	public static func getMimeTypeFromFileExtension(_ ext: String) -> String? {
		guard let uti = getUtiTypeFromFileExtension(ext), let mime = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
	
	public static func getMimeTypeFromUti(_ uti: String) -> String? {
		guard let mime = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
}
