//
//  RequestPluginType.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 27.01.17.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import Foundation

/// Plugin that receives callbacks from HttpClient and StreamDataTask
/// HttpClient calls only prepare method, all onter methods are called by StreamDataTask
public protocol RequestPluginType {
	/// HttpClient calls this method before creting actual URLSessionDataTask (and StreamDataTask)
	func prepare(request: URLRequest) -> URLRequest
	/// Called right before StreamDataTask starts underluing URLSessionDataTask
	func beforeSend(request: URLRequest)
	/// Called after StreamDataTask received didCompleteWithError event from URLSession 
	///(and this method does not contain error)
	func afterSuccess(response: URLResponse?, data: Data?)
	/// Called after StreamDataTask received didCompleteWithError with error or if HTTPURLResponse status code is not within 200...299 range.
	/// Also this method is callded if StreamDataTask receives didBecomeInvalidWithError event from URLSession
	func afterFailure(response: URLResponse?, error: Error, data: Data?)
}

/// Plugin that holds collection of plugins and send all events to them
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
