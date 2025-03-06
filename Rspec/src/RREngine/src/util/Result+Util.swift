//
//  Result+Util.swift
//  RREngine
// 
//  Created on 7/18/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  A result that assumes either success or an error code.
public typealias ResultBool = Result<Bool, Error>

/*
 *  Utilities for boolean results.
 */
extension ResultBool {
	/// Identifies whether the boolean result was successful.
	public var isOk: Bool {
		guard case .success(_) = self else { return false }
		return true
	}
	
	/// Attempt to resolve the result as an error.
	public var asError: Error? {
		guard case .failure(let err) = self else { return nil }
		return err
	}

	/// Convenience symbol for initializing boolean results.
	public static var success: Self { return .success(true) }
}
