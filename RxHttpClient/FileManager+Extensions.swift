import Foundation

extension FileManager {
	@nonobjc func fileExists(atPath path: String, isDirectory: Bool = false) -> Bool {
		var isDir = ObjCBool(isDirectory)
		return fileExists(atPath: path, isDirectory: &isDir)
	}
}
