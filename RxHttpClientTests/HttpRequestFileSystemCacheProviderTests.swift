//
//  HttpRequestFileSystemCacheProviderTests.swift
//  RxHttpClient
//
//  Created by Anton Efimenko on 27.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
@testable import RxHttpClient

extension FileManager {
    @nonobjc func fileExists(atPath path: String, isDirectory: Bool = false) -> Bool {
        var isDir = ObjCBool(isDirectory)
        return fileExists(atPath: path, isDirectory: &isDir)
    }
}

class HttpRequestFileSystemCacheProviderTests: XCTestCase {
	var cacheDirectory: URL!
	override func setUp() {
		cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(UUID().uuidString)
		try! FileManager.default.createDirectory(atPath: cacheDirectory.path, withIntermediateDirectories: false, attributes: nil)
	}
	
	override func tearDown() {
		try! FileManager.default.removeItem(at: cacheDirectory)
	}
	
	func testSave() {
		print(cacheDirectory.absoluteString)
		let provider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
		let data = "some test string".data(using: .utf8)!
		let url = URL(string: "https://google.com")!
		provider.save(resourceUrl: url, data: data)
		
		let cachedData = try? Data(contentsOf: cacheDirectory.appendingPathComponent(url.sha1()))
		XCTAssertTrue(cachedData?.elementsEqual(data) ?? false, "Cached data should be equal to sended data")
	}
	
	func testOverwriteData() {
		let provider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
		var data = "some test string".data(using: .utf8)!
		let url = URL(string: "https://test.com")!
		provider.save(resourceUrl: url, data: data)
		
		data = "some new data that should overwrite old".data(using: .utf8)!
		provider.save(resourceUrl: url, data: data)
		
		let cachedData = try? Data(contentsOf: cacheDirectory.appendingPathComponent(url.sha1()))
		XCTAssertTrue(cachedData?.elementsEqual(data) ?? false, "Cached data should be equal to sended data")
	}
	
	func testLoad() {
		let url = URL(string: "https://random.com")!
		let data = "some saved data".data(using: .utf8)!
		try! data.write(to: cacheDirectory.appendingPathComponent(url.sha1()))
		
		let provider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
		let loadedData = provider.load(resourceUrl: url)
		XCTAssertTrue(loadedData?.elementsEqual(data) ?? false, "Loaded data should be equal to saved")
	}
	
	func testLoadNotExisted() {
		let url = URL(string: "https://random.com")!
		let provider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
		XCTAssertNil(provider.load(resourceUrl: url), "Should return nil")
	}
	
	func testClear() {
		let data = "some saved data".data(using: .utf8)!
		try! data.write(to: cacheDirectory.appendingPathComponent(UUID().uuidString))
		try! data.write(to: cacheDirectory.appendingPathComponent(UUID().uuidString))
		try! data.write(to: cacheDirectory.appendingPathComponent(UUID().uuidString))
		
		XCTAssertEqual(try! FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count, 3)
		
		let provider = UrlRequestFileSystemCacheProvider(cacheDirectory: cacheDirectory)
		provider.clear()
	
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDirectory.path, isDirectory: true))
		XCTAssertEqual(try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count, 0)
	}
}
