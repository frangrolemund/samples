//
//  MDError.swift
//  MetDesigner
// 
//  Created on 1/26/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  Met Designer error codes.
 */
enum MDError : LocalizedError {
	case brokenInvariant(_ msg: String)
	case invalidDocument
	
	// - generate a viewable error message.
	var errorDescription: String? {
		switch self {
		case .brokenInvariant(let msg):
			return "A fundamental assertion was violated.  \(msg)"
			
		case .invalidDocument:
			return "The document does not contain the expected content."
		}
	}
}
