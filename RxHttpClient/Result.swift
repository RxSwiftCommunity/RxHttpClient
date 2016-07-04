import Foundation

public protocol ResultType { }
extension Result : ResultType { }

public enum Result<T> {
	case success(Box<T>)
	case error(ErrorType)
}

public class Box<T> {
	public let value: T
	
	public init(value: T) {
		self.value = value
	}
}