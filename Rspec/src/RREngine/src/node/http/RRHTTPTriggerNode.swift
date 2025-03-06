//
//  RRHTTPTriggerNode.swift
//  RREngine
// 
//  Created on 12/28/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  A Node that that generates HTTP events.
@MainActor
public final class RRHTTPTriggerNode : RRTriggerNode {
}

extension RRHTTPTriggerNode : RRDefaultNodeBuildable {
	/*
	 *  Create a default HTTP trigger.
	 */
	static func buildDefaultNode(in environment: RREngineEnvironment) -> RRHTTPTriggerNode {
		return RRHTTPTriggerNode(with: Config(), in: environment)
	}
}

/*
 *  Types
 */
extension RRHTTPTriggerNode {
	struct Config : RRNodeConfigurable {
		var name: String?
		var defaultPortNumber: NetworkPortValue?
		var clientBacklog: UInt16
		
		init() {
			self.name 			   = nil
			self.defaultPortNumber = nil
			self.clientBacklog	   = RRHTTPFirewallPort.Config.DefaultClientBacklog
		}
	}
}

/*
 *  Accessors
 */
@MainActor
extension RRHTTPTriggerNode {
	/// The default TCP port that will be open for client connections.
	var defaultPortNumber: NetworkPortValue? {
		get { self.config.defaultPortNumber }
		set { self.config.defaultPortNumber = newValue }
	}
	
	/// The number of
	var clientBacklog: UInt16 {
		get { self.config.clientBacklog }
		set { self.config.clientBacklog = newValue }
	}
}

/*
 *  Internal implementation.
 */
extension RRHTTPTriggerNode : RRActiveDynamoInternal {
	/*
	 *  Create a runtime instance.
	 */
	nonisolated func buildRuntime(with env: RREngineEnvironment?) -> RRHTTPTriggerNodeRuntime? {
		return RRHTTPTriggerNodeRuntime(with: env, config: self.config)
	}
}
