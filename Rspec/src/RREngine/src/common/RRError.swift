//
//  RRError.swift
//  RREngine
// 
//  Created on 7/17/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  Engine error definitions
public enum RRError : LocalizedError, Equatable {
	/// A failure in internal processing.
	case assertionFailed
	
	/// Invalid arguments to a method.
	case badArguments
	
	/// The engine is incompatible with the requested operation.  Includes a context of the type of error encountered.
	case engineVersionMismatch(context: String)
	
	/// The entity is offline.
	case notProcessing
	
	/// The request is unsupported.
	case notSupported
	
	/// A required repository file was not found.
	case repoResourceNotFound(_ name: String)
	
	/// A required repository file could not be loaded successfully.
	case repoResourceInvalid(_ name: String, _ message: String)
	
	/// A textual error description.
	public var errorDescription: String? {
		switch self {
		case .assertionFailed:
			return "An programmatic invariant has been violated."
			
		case .badArguments:
			return "One or more arguments are invalid."
			
		case .engineVersionMismatch(let context):
			return "The engine is incompatible with the requested operation.  \(context)"
			
		case .notProcessing:
			return "The requested entity is no longer processing."
			
		case .notSupported:
			return "The requested operation is not supported."
			
		case .repoResourceNotFound(let name):
			return "The repository resource \"\(name)\" was not found."
			
		case .repoResourceInvalid(let name, let message):
			return "The repository resource \"\(name)\" is an invalid format. \(message)"
		}
	}
}
