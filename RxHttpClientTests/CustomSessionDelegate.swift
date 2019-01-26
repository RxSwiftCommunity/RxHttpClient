//
//  CustomSessionDelegate.swift
//  RxHttpClientTests
//
//  Created by Anton Efimenko on 26/01/2019.
//  Copyright © 2019 RxSwiftCommunity. All rights reserved.
//

import XCTest
import RxHttpClient
import RxSwift
import OHHTTPStubs

class AlwaysFail: NSURLSessionDataEventsObserver {
    override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // response with static statusCode
        let response = HTTPURLResponse(url: response.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        sessionEventsSubject.onNext(.didReceiveResponse(session: session, dataTask: dataTask, response: response, completion: completionHandler))
    }
}

class CustomSessionDelegate: XCTestCase {
    func testOwerrideResponse() {
        let sendData = "testData".data(using: String.Encoding.utf8)!
        let _ = stub(condition: { $0.url?.absoluteString == "https://test.com/json" && $0.httpMethod == HttpMethod.get.rawValue    }) { _ in
            return OHHTTPStubsResponse(data: sendData, statusCode: 200, headers: nil)
        }
        
        let client = HttpClient(sessionConfiguration: .default, sessionDelegate: AlwaysFail())
        let url = URL(baseUrl: "https://test.com/json", parameters: nil)!
        let bag = DisposeBag()
        
        let expectation = self.expectation(description: "Should return error")
        
        client.requestData(url: url).subscribe(onNext: { _ in XCTFail("Should not emit data") }, onError: { result in
            guard case let HttpClientError.invalidResponse(response, data) = result else { return }
            XCTAssertEqual(response.statusCode, 500, "Check correct status code")
            XCTAssertEqual(true, data == sendData, "Check received data is still correct")
            expectation.fulfill()
        }).disposed(by: bag)
        
        waitForExpectations(timeout: 1, handler: nil)
    }
}
