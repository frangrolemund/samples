//
//  RRVersion.swift
//  RREngine
// 
//  Created on 10/5/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/// Semantic version identifier.
public struct RRVersion : Codable, Comparable, CustomStringConvertible {
	/// The dominant software version number.
	public let major: UInt
	
	/// The supporting software version number.
	public let minor: UInt
	
	/// The fix-level version number.
	public let patch: UInt

	/// A textual description of the version.
	public var description: String {
		return "\(major).\(minor).\(patch)"
	}

	/// Initialize the object.
	///  - Parameter major: The dominant version number.
	///  - Parameter minor: The supporting version number.
	///  - Parameter patch: The fix-level version number.
	public init(_ major: UInt, _ minor: UInt = 0, _ patch: UInt = 0) {
		self.major = major
		self.minor = minor
		self.patch = patch
	}

	/// Initialize the object.
	///  - Parameter text: The version number formatted as `#.#.#`.
	public init(with text: String) throws {
		// ...only major is required, but otherwise allows semantic versioning.
		let regex = #/(\d+)(?:\.(\d+))?(?:\.(\d+))?/#
		guard let match = text.wholeMatch(of: regex) else {
			throw RRError.badArguments
		}
		self.init(.init(match.1) ?? 0, .init(match.2 ?? "0") ?? 0, .init(match.3 ?? "0") ?? 0)
	}

	/// Compare two version numbers using the < operator.
	///  - Parameter lhs: The version being compared.
	///  - Parameter rhs: The version being compared against.
	///  - Returns: A `Bool` value indicating whether the `lhs` version is less than the `rhs` version.
	public static func < (lhs: RRVersion, rhs: RRVersion) -> Bool {
		if lhs.major < rhs.major { return true }
		if lhs.major == rhs.major {
			if lhs.minor < rhs.minor { return true }
			if lhs.minor == rhs.minor {
				if lhs.patch < rhs.patch { return true }
			}
		}
		return false
	}
}
