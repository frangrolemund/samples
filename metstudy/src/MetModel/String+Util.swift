//
//  String+Util.swift
//  MetModel
// 
//  Created on 1/30/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import CryptoKit

/*
 *  Utilities.
 */
extension String {
	/*
	 *  Convenience initializer that uses the right bundle.
	 */
	static func mmLocalized(localized keyAndValue: String.LocalizationValue, comment: StaticString? = nil) -> String {
		return String(mmLocalized: keyAndValue, comment: comment)
	}
	
	/*
	 *  Convenience initializer that uses the right bundle.
	 *  DESIGN: This is important in the framework because its bundle is different than the main process.
	 */
	init(mmLocalized keyAndValue: String.LocalizationValue, comment: StaticString? = nil) {
		self.init(localized: keyAndValue, bundle: .metModel, comment: comment)
	}
	
	/*
	 *  Compute a SHA hash of the provided string.
	 */
	var shaHash: String {
		guard let data = self.data(using: .utf8) else {
			assert(false, "Unable to convert '\(self)' to UTF-8 data.")
			return "invalid"
		}
		var hash = Insecure.MD5()		// - good enough and not super-long
		hash.update(data: data)
		let digest = hash.finalize()
		return digest.withUnsafeBytes { ptr in
			ptr.map({String(format: "%02x", $0)}).joined()
		}
	}
}

extension LocalizedStringResource {
	/*
	 *  Convenience initializer that uses the right bundle.
	 */
	static func mmLocalized(localized keyAndValue: String.LocalizationValue, comment: StaticString? = nil) -> LocalizedStringResource {
		return LocalizedStringResource(stringLiteral: .mmLocalized(localized: keyAndValue, comment: comment))
	}
}
