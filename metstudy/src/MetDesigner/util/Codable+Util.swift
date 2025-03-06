//
//  Codable+Util.swift
//  MetDesigner
// 
//  Created on 1/26/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  Utilities.
 */
extension Encodable {
	/*
	 *  Standard JSON encoding for the designer files.
	 */
	func standardDesignerJSONEncoding(isPretty: Bool = true) throws -> Data {
		let je 					= JSONEncoder()
		je.dateEncodingStrategy = .iso8601
		je.dataEncodingStrategy = .base64
		if isPretty {
			je.outputFormatting	= [.prettyPrinted]
		}
		return try je.encode(self)
	}
}

extension Decodable {
	/*
	 *  Standard JSON decoding for the designer files.
	 */
	static func standardDesignerJSONDecoding<T: Decodable>(from data: Data) throws -> T {
		let jd 					= JSONDecoder()
		jd.dateDecodingStrategy = .iso8601
		jd.dataDecodingStrategy	= .base64
		return try jd.decode(T.self, from: data)
	}
}
