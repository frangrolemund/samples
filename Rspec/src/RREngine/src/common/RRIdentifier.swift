//
//  RRIdentifier.swift
//  RREngine
// 
//  Created on 7/11/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/// uniquely identifies all key entities of the engine and repository.
public typealias RRIdentifier = UUID

/// standard identification for realrouted entities.
public protocol RRIdentifiable : Identifiable {
	var id: RRIdentifier { get }
}

// - Utilities.
extension RRIdentifier {
	public var briefId: String { self.uuidString.prefix(8).lowercased() }
}
