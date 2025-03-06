//
//  Codable+Util.swift
//  MetModel
// 
//  Created on 1/25/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  Utilities.
 */
extension Encodable {
	/*
	 *  Encode the type consistently.
	 */
	func standardMMJSONEncoding() throws -> Data {
		let je 					= JSONEncoder()
		je.dateEncodingStrategy = .iso8601
		je.dataEncodingStrategy	= .base64
		je.outputFormatting		= [.prettyPrinted]
		return try je.encode(self)
	}
}

extension Decodable {
	/*
	 *  Decode the type consistently.
	 */
	static func standardMMJSONDecoding(of data: Data) throws -> Self {
		let jd 					= JSONDecoder()
		jd.dateDecodingStrategy = .iso8601
		jd.dataDecodingStrategy	= .base64
		return try jd.decode(self, from: data)
	}
}

extension DecodingError : MMErrorDebuggable {
	public var mmDebuggableText: String? {
		let context: DecodingError.Context
		let msg: String
		switch self {
		case .keyNotFound(let ck, let ctx):
			msg = "The key '\(ck.stringValue)' was not found."
			context = ctx
			
		case .typeMismatch(let t, let ctx):
			msg = "There is a type mismatch for the \(String(describing: t)) value."
			context = ctx
			
		case .dataCorrupted(let ctx):
			msg = "Data appears corrupted."
			context = ctx
			
		case .valueNotFound(let v, let ctx):
			msg = "The value of type \(String(describing: v)) was not found."
			context = ctx
			
		default:
			assert(false, "Unsupported value, upgrade handling here.")
			return "Unsupported decoding error result."
		}
		
		let kPath = context.codingPath.reduce("") { partialResult, ck in
			let sValue = ck.stringValue.replacingOccurrences(of: " ", with: "-")
			return partialResult.isEmpty ? sValue : "\(partialResult).\(sValue)"
		}
		
		return "Decoding error detected.  \(msg)  \(context.debugDescription)  keypath: \(kPath)"
	}
}
