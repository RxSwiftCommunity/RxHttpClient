import Foundation


extension Data {
	func sha1() -> String {
		var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
		withUnsafeBytes {
			_ = CC_SHA1($0, CC_LONG(count), &digest)
		}
		let hexBytes = digest.map { String(format: "%02hhx", $0) }
		return hexBytes.joined()
	}
}
