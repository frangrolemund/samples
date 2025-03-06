//
//  XCTestCase+Util.swift
//  MetModelTests
// 
//  Created on 1/18/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import XCTest
import OSLog

/*
 *  Utilities for testing.
 */
extension XCTestCase {
	var log: Logger { .init(subsystem: "com.metmodel.tests", category: "MetModelTests") }
	
	/*
	 *  Return the location of test data.
	 */
	var testDataDirectory: URL {
		var ret = URL(string: #filePath)!
		ret.deleteLastPathComponent()
		ret.append(component: "data", directoryHint: .isDirectory)
		return ret
	}
	
	/*
	 *  Returns a specific data file item.
	 */
	func testDataURLForFile(_ named: String) -> URL {
		return testDataDirectory.appending(path: named)
	}
	
	/*
	 *  Encode a value as JSON.
	 */
	func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
		let je				    = JSONEncoder()
		je.outputFormatting 	= [.prettyPrinted, .sortedKeys]
		je.dateEncodingStrategy = .iso8601
		je.dataEncodingStrategy = .base64
		return try je.encode(value)
	}
	
	/*
	 *  Decode a value from JSON.
	 */
	func decodeJSON<T: Decodable>(_ item: Data) throws -> T {
		let jd 					= JSONDecoder()
		jd.dateDecodingStrategy = .iso8601
		jd.dataDecodingStrategy = .base64
		return try jd.decode(T.self, from: item)
	}
}
