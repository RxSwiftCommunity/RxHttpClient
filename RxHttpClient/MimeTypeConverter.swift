import Foundation
import MobileCoreServices

public struct MimeTypeConverter {
	public static func getUtiFromMime(mimeType: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, nil) else { return nil }
		
		return contentType.takeRetainedValue() as String
	}
	
	public static func getFileExtensionFromUti(utiType: String) -> String? {
		guard let ext = UTTypeCopyPreferredTagWithClass(utiType, kUTTagClassFilenameExtension) else { return nil }
		
		return ext.takeRetainedValue() as String
	}
	
	public static func getUtiTypeFromFileExtension(ext: String) -> String? {
		guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, nil) else { return nil }
		return contentType.takeRetainedValue() as String
	}
	
	public static func getFileExtensionFromMime(mimeType: String) -> String? {
		guard let uti = getUtiFromMime(mimeType) else { return nil }
		return getFileExtensionFromUti(uti)
	}
	
	public static func getMimeTypeFromFileExtension(ext: String) -> String? {
		guard let uti = getUtiTypeFromFileExtension(ext), mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
	
	public static func getMimeTypeFromUti(uti: String) -> String? {
		guard let mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType) else { return nil }
		return mime.takeRetainedValue() as String
	}
}