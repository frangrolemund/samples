//
//  RREngine+State.swift
//  RREngine
// 
//  Created on 10/16/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  The runtime state of the engine.
 */
struct RREngineState : RRStatefulProcessor, RRLoggableCategory {
	static var logCategory: String? { "Engine" }
	
	// - whether the engine is paused for processing
	var isEnginePaused: Bool

	// - the control path for networking into the engine
	var firewall: RRFirewall
	
	// - organizes firewall entities into a common threading context
	let fwContext: RRFirewallContext
	
	// - the running nodes in the engine.
	private (set) var nodeMap: RRNodeMap
		
	/*
	 *  Initialize the object.
	 */
	init(with environment: RREngineEnvironment, andNodeMap nodeMap: RRNodeMap = [:]) {
		// - DESIGN: The engine should be paused by default when the engine is first 
		//			 loaded/initialized because standard document patterns on macOS allow
		//  		 multiple instances of the same engine to exist at a time and it is likely
		// 			 easier to have it do nothing while following an unmodified configuration
		// 	 		 phase than to conditionally configure it.
		self.isEnginePaused = true
		self.firewall  		= .init(in: environment)
		self.fwContext 		= .init()
		self.nodeMap   		= nodeMap
	}
	
	/*
	 *  Shut down the state.
	 */
	func shutdown() async -> RRShutdownResult {
		var ret: RRShutdownResult = .success
		let desc = "the engine"
		logBeginShutdown(desc)
		
		// - shut down all the nodes
		for n in nodeMap.values {
			ret.append(await n.shutdown())
		}
		
		// - now each subsystem
		ret.append(await self.firewall.shutdown())
		ret.append(await self.fwContext.shutdown())
		
		logEndShutdown(desc, result: ret)
		return ret
	}
}

typealias RRNodeMap = [ RRIdentifier : RRNode ]

/*
 *  Accessors.
 */
extension RREngineState {
	/*
	 *  Insert a node into the engine state.
	 */
	mutating func insert(_ node: RRNode) {
		self.nodeMap[node.id] = node
	}
	
	/*
	 *  Replace the entire node map.
	 */
	mutating func replace(nodeMap: RRNodeMap) {
		self.nodeMap = nodeMap
	}
}
