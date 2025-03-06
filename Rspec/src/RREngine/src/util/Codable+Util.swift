//
//  Codable+Util.swift
//  RREngine
// 
//  Created on 9/30/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  Utilities.
 */
public extension Encodable {
	/*
	 *  Encode the value in a consistent manner.
	 */
	func rrEncoding() throws -> Data {
		let je = JSONEncoder.standardRREncoder
		return try je.encode(self)
	}
}

/*
 *  Utilieis.
 */
public extension Decodable {
	/*
	 *  Decode the value in a consistent manner.
	 */
	static func rrDecoding(from data: Data) throws -> Self {
		let jd = JSONDecoder.standardRRDecoder
		return try jd.decode(Self.self, from: data)
	}
}

/*
 *  Utilities
 */
public extension JSONEncoder {
	// - a JSON encoder with consistent attributes.
	static var standardRREncoder: JSONEncoder {
		let ret					 = JSONEncoder()
		ret.outputFormatting	 = [.prettyPrinted, .sortedKeys]
		ret.dateEncodingStrategy = .iso8601
		ret.dataEncodingStrategy = .base64
		return ret
	}
}

/*
 *  Utilities.
 */
public extension JSONDecoder {
	// - a JSON decoder with consistent attributes.
	static var standardRRDecoder: JSONDecoder {
		let ret 				 = JSONDecoder()
		ret.dateDecodingStrategy = .iso8601
		ret.dataDecodingStrategy = .base64
		return ret
	}
}
