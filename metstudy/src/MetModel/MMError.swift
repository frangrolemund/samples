//
//  MMError.swift
//  MetModel
// 
//  Created on 1/17/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/// MetModel error types.
public enum MMError : LocalizedError, MMErrorDebuggable {
	///  The arguments are invalid
	case badArguments(msg: LocalizedStringResource)
	
	///  The data format is invalid or unexpected.
	case badFormat(msg: LocalizedStringResource)
	
	///  The operation was cancelled.
	case cancelled
	
	///  A fundamental assertion failed, assume it is a bug.
	case failedAssertion
	
	///  A file access error occurred, returning the libC errno value.
	case fileError(errno: Int32)
	
	///  The file could not be opened or is invalid.
	case invalidFile
	
	///  A networking error ocurred.
	case httpError(statusCode: Int?, msg: String?)
	
	///  The requested entity was not found.
	case notFound
	
	public var errorDescription: String? {
		switch self {
		case .badArguments(_):
			return .mmLocalized(localized: "One or more provided arguments are invalid.", comment: "The arguments passed to a method did not match expectations.")
			
		case .badFormat(_):
			return .mmLocalized(localized: "The file data is invalid or unexpected.", comment: "The format of a file being imported into the data model is incorrect.")
			
		case .cancelled:
			return .mmLocalized(localized: "The operation was cancelled.", comment: "Error that occurs when a long-running asynchronous operation was cancelled.")
			
		case .failedAssertion:
			return .mmLocalized(localized: "A fundamental asumption could not be satisfied.", comment: "An internal failure occurred that was unexpected and is most certainly a bug.")

		case .fileError(_):
			return .mmLocalized(localized: "Unable to read or write the associated file", comment: "A failure occurred while interacting with an open on-disk file.")
			
		case .invalidFile:
			return .mmLocalized(localized: "The file could not be opened or is invalid.", comment: "A failure occurred attempting to open an on-disk file.")
			
		case .httpError(_, _):
			return .mmLocalized(localized: "A network request for an online data has failed.", comment: "A failure occurred attempting make a network request.")
			
		case .notFound:
			return .mmLocalized(localized: "The requested entity was not found.")
		}
	}
	
	/// Model-specific debugging text for the error.
	public var mmDebuggableText: String? { failureReason }
	
	public var failureReason: String? {
		switch self {
		case .badArguments(let msg):
			return String(localized: msg)
			
		case .badFormat(let msg):
			return String(localized: msg)
			
		case .cancelled:
			return nil
			
		case .failedAssertion:
			return .mmLocalized(localized: "There is an unexpected bug in the data modeling API.")
			
		case .fileError(let errno):
			return .mmLocalized(localized: "The system reported libC errno of \(errno).")
			
		case .invalidFile:
			return String(localized: "The file could not be accessed at the provided location.")
			
		case .httpError(let statusCode, let msg):
			let sText: String = (statusCode != nil) ? "HTTP Status: \(statusCode!)." : ""
			let sMsg: String  = msg ?? ""
			let suffix: String = "\(sText)\(sText.isEmpty && sMsg.isEmpty ? "" : " ")\(sMsg)"
			return String(localized: "The HTTP request has failed.\(suffix)")
			
		case .notFound:
			return nil
		}
	}
}

/// Error debugging facilities.
public protocol MMErrorDebuggable : Error {
	/// Model-specific debugging text for the error.
	var mmDebuggableText: String? { get }
}
