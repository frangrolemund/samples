//
//  RRHTTPTriggerNode+Runtime.swift
//  RREngine
// 
//  Created on 12/28/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  The runtime for the HTTP trigger.
 */
class RRHTTPTriggerNodeRuntime : RRDynamoRuntime<RRHTTPTriggerNode.Config, Bool> {
	// - build the runtime state.
	override func buildRuntimeState() -> Bool { true }
}
