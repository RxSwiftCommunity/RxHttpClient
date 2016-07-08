//
//  MimeTypeConverterTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 06.07.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
import RxHttpClient

class MimeTypeConverterTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testConvertExtensionToUti() {
		XCTAssertEqual(MimeTypeConverter.getUtiTypeFromFileExtension("mp3"), "public.mp3")
	}
	
	func testConvertExtensionToMime() {
		XCTAssertEqual(MimeTypeConverter.getMimeTypeFromFileExtension("mp3"), "audio/mpeg")
	}
	
	func testConvertMimeToUti() {
		XCTAssertEqual(MimeTypeConverter.getUtiFromMime("audio/mpeg"), "public.mp3")
	}
	
	func testConvertMimeToExtension() {
		XCTAssertEqual(MimeTypeConverter.getFileExtensionFromMime("audio/mpeg"), "mp3")
	}
	
	func testConvertUtiTiMime() {
		XCTAssertEqual(MimeTypeConverter.getMimeTypeFromUti("public.mp3"), "audio/mpeg")
	}
	
	func testConvertUtiToExtension() {
		XCTAssertEqual(MimeTypeConverter.getFileExtensionFromUti("public.mp3"), "mp3")
	}
}