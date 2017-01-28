//
//  RequestPluginType.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 27.01.17.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import Foundation

public protocol RequestPluginType {
	func prepare(request: URLRequest) -> URLRequest
	func beforeSend(request: URLRequest)
	func afterSuccess(response: URLResponse?, data: Data?)
	func afterFailure(response: URLResponse?, error: Error, data: Data?)
}

public final class CompositeRequestPlugin : RequestPluginType {
	let plugins: [RequestPluginType]
	
	public init(plugins: [RequestPluginType]) {
		self.plugins = plugins
	}
	
	public init(plugins: RequestPluginType...) {
		self.plugins = plugins
	}
	
	public func prepare(request: URLRequest) -> URLRequest {
		return plugins.reduce(request, { $0.1.prepare(request: $0.0) })
	}
	
	public func beforeSend(request: URLRequest) {
		plugins.forEach { $0.beforeSend(request: request) }
	}
	
	public func afterFailure(response: URLResponse?, error: Error, data: Data?) {
		plugins.forEach { $0.afterFailure(response: response, error: error, data: data) }
	}
	
	public func afterSuccess(response: URLResponse?, data: Data?) {
		plugins.forEach { $0.afterSuccess(response: response, data: data) }
	}
}
