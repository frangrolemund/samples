//
//  RREngine+Debug.swift
//  RREngine
// 
//  Created on 10/17/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  TEMPORARY:  A primitive to be used for debugging the port implementation.
 */
class RRDebugTriggerNode : RRNode {
	override var name: String? {
		get { super.name ?? "DebugTrigger" }
		set { super.name = newValue }
	}
	
	nonisolated init(in environment: RREngineEnvironment) {
		super.init(with: Config(), in: environment)
	}
	
	required init(from decoder: Decoder) throws {
		try super.init(from: decoder)
	}
	
	override func dynamoDidLoad() {
		super.dynamoDidLoad()
		self.environment.firewall.connectPort(ofType: .http, toTrigger: self)
	}
}

extension RRDebugTriggerNode : RRStaticNodeInternal {
	struct Config : RRNodeConfigurable {
		var name: String?
		var value: Int = 3
	}
	
	struct State : RRStaticDynamoStateful {
		var text: String = ""
	}
	
	func buildState() -> State {
		return State()
	}
}
