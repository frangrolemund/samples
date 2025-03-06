//
//  RRNode.swift
//  RREngine
// 
//  Created on 11/23/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  An independent unit of concurrent processing that interprets
///  and/or generates messages between itself and a larger data
///  flow network of zero or more other nodes.
@MainActor
public class RRNode : RRDynamoCodable {
	/// A human-readable name of the node to identify its design purpose.
	var name: String? {
		get { (self.__config as? any RRNodeConfigurable)?.name }
		set { updateConfiguration(with: { $0.name = newValue }) }
	}
}

/*
 *  Nodes are most often created in response to UI requests that require
 *  a sensible default to be created.  The engine calls this method using
 *  an input node type as reference.
 */
protocol RRDefaultNodeBuildable : RRNode {
	static func buildDefaultNode(in environment: RREngineEnvironment) -> Self
}
extension RRDefaultNodeBuildable {
	static func buildDefaultNode(in environment: RREngineEnvironment) -> Self {
		assert(false, "Default node implementation is required.")
		fatalError()
	}
}

/*
 *  All nodes are expected to adopt this protocol for configuration.
 */
protocol RRNodeConfigurable : RRDynamoCodableConfigurable {
	// ...an optional human-readable name assigned to the node.
	var name: String? { get set }
}

/*
 *  Internal.
 */
extension RRNode {
	/*
	 *  Convenience method for updating configuration.
	 *  DESIGN: because the configuration is loosely typed at this stage,
	 *  		any changes must be more carefully applied to avoid races or
	 * 			inconsistencies.
	 */
	private func updateConfiguration(with block: (_ config: inout any RRNodeConfigurable) -> Void) {
		self.withLock {
			guard var cfg = (self.__config as? any RRNodeConfigurable) else { return }
			block(&cfg)
			self.__config = cfg
		}
	}
}
