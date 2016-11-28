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
	
	func testNotConvertExtensionToMime() {
		XCTAssertNil(MimeTypeConverter.getMimeTypeFromFileExtension("wrngExtension"))
	}
	
	func testNotConvertMimeToExtension() {
		XCTAssertNil(MimeTypeConverter.getFileExtensionFromMime("wrong/mime"))
	}
	
	func testNotConvertUtiToMime() {
		XCTAssertNil(MimeTypeConverter.getMimeTypeFromUti("wrong.uti"))
	}
	
	func testNotConvertUtiToExtension() {
		XCTAssertNil(MimeTypeConverter.getFileExtensionFromUti("wrong.uti"))
	}
	
	func testShortConvertExtensionToUti() {
		XCTAssertEqual("mp3".asFileExtension.utiType, "public.mp3")
	}
	
	func testShortConvertExtensionToMime() {
		XCTAssertEqual("mp3".asFileExtension.mimeType, "audio/mpeg")
	}
	
	func testShortConvertMimeToUti() {
		XCTAssertEqual("audio/mpeg".asMimeType.utiType, "public.mp3")
	}
	
	func testShortConvertMimeToExtension() {
		XCTAssertEqual("audio/mpeg".asMimeType.fileExtension, "mp3")
	}
	
	func testShortConvertUtiTiMime() {
		XCTAssertEqual("public.mp3".asUtiType.mimeType, "audio/mpeg")
	}
	
	func testShortConvertUtiToExtension() {
		XCTAssertEqual("public.mp3".asUtiType.fileExtension, "mp3")
	}
	
	func testShortNotConvertExtensionToMime() {
		XCTAssertNil("wrngExtension".asFileExtension.mimeType)
	}
	
	func testShortNotConvertMimeToExtension() {
		XCTAssertNil("wrong/mime".asMimeType.fileExtension)
	}
	
	func testShortNotConvertUtiToMime() {
		XCTAssertNil("wrong.uti".asUtiType.mimeType)
	}
	
	func testShortNotConvertUtiToExtension() {
		XCTAssertNil("wrong.uti".asUtiType.fileExtension)
	}
}
