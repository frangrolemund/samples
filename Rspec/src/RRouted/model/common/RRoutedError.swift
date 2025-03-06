//
//  RRoutedError.swift
//  RRouted
// 
//  Created on 11/11/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import RREngine

/*
 *  App-specific error definitions.
 */
enum RRoutedError : LocalizedError, Equatable {
	case invalidFormat(reason: String)
	case portConflict(id: RRIdentifier, idOther: RRIdentifier)
	
	/*
	 *  Check for equality.
	 */
	static func == (lhs: RRoutedError, rhs: RRoutedError) -> Bool {
		switch lhs {
		case .invalidFormat(_):
			return lhs.errorDescription == rhs.errorDescription
			
		case .portConflict(let lhId, let lhIdOther):
			if case .portConflict(let rhId, let rhIdOther) = rhs, rhId == lhId, rhIdOther == lhIdOther {
				return true
			}
		}
		return false
	}
	
	/*
	 *  Convert into an error message.
	 */
	var errorDescription: String? {
		switch self {
		case .invalidFormat(let reason):
			return "The text is not formatted correctly for the expected data.  \(reason)"

		case .portConflict(let id, let idOther):
			return "The port configuration of \(id.uuidString) conflicts with the configuration of \(idOther.uuidString) in the firewall."
		}
	}
}
