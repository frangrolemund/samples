//
//  RRDynamo+Internal.swift
//  RREngine
// 
//  Created on 10/11/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  Dynamos are configured using easily shared entities between their
 *  model and their runtime.
 */
protocol RRDynamoConfigurable : Sendable, Equatable {
	
}

extension RRDynamoConfigurable {
	// - check for equality with another arbitrary configurable.
	func equals(_ other: any RRDynamoConfigurable) -> Bool {
		guard let other = other as? Self else { return false }
		return self == other
	}
}

/*
 *  The common internal implementation of a dynamo which is left
 *  as a protocol to obscure the generic requirements from the
 *  public interfaces.
 *  DESIGN:  It is *very* important to remember that Dynamos are designed to
 * 	 		 be _aggregated, not inherited_ in practice.  Once an internal variant
 * 			 is built, it should be declared as `final` as a rule.
 */
protocol RRDynamoInternal : RRDynamo {
	nonisolated func __buildRuntime(with env: RREngineEnvironment?) -> (any RRDynamoStatefulManager)?
	nonisolated static var codableConfigurationType: (any RRDynamoCodableConfigurable.Type)? { get }
}
extension RRDynamoInternal {
	nonisolated static var codableConfigurationType: (any RRDynamoCodableConfigurable.Type)? { nil }
}
