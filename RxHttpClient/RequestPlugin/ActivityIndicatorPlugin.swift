//
//  ActivityIndicatorPlugin.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 28.01.17.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import Foundation
import UIKit

protocol UIApplicationType : class {
	var isNetworkActivityIndicatorVisible: Bool { get set }
}

extension UIApplication : UIApplicationType { }

public final class NetworkActivityIndicatorPlugin : RequestPluginType {
	let application: UIApplicationType
	
	var counter = 0 {
		didSet {
			application.isNetworkActivityIndicatorVisible = counter != 0
		}
	}
	
	public init(application: UIApplication) {
		self.application = application
	}
	
	init(applicationType: UIApplicationType) {
		self.application = applicationType
	}
	
	public func prepare(request: URLRequest) -> URLRequest {
		return request
	}
	
	public func beforeSend(request: URLRequest) {
		counter += 1
	}
	
	public func afterFailure(response: URLResponse?, error: Error, data: Data?) {
		counter -= 1
	}
	
	public func afterSuccess(response: URLResponse?, data: Data?) {
		counter -= 1
	}
}
