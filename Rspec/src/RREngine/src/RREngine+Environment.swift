//
//  RREngine+Environment.swift
//  RREngine
// 
//  Created on 9/28/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog
import Combine

/*
 *  DESIGN:  The engine environment _is_ the implementation of the engine used
 * 			 internally by all the connected subsystems.  It is designed to be
 * 			 observable so that it can communicate configuration changes naturally
 * 	 		 to the engine and later to a document while remaining largely
 *  		 nonisolated to provide integration across all isolation contexts
 * 			 supporting documents, dynamos and runtimes.
 *  DESIGN:  Since it manages all the system dynamos, it is not itself a dynamo.
 */
final class RREngineEnvironment : RRStatefulProcessor {
	var operatingStatus: RROperatingStatus { (self._operatingStatus == .running && self.isEnginePaused) ? .paused : self._operatingStatus }

	// - when the environment is changed with systemwide implications, it will publish through this path.
	var changePublisher: AnyPublisher<ChangeType, Never> { self.changeSubject.eraseToAnyPublisher() }
	
	/*
	 *  Initialize the environment.
	 */
	convenience init() {
		self.init(with: .init(id: .init()))
	}
	
	/*
	 *  Initialize the environment from an archive.
	 */
	init(with config: RREngineConfig) {
		// - initialize the pair of configuration and state.
		self.runtime.value = .init(config: config, state: .init(with: self, andNodeMap: [:]))
		self._cachedFW     = self.state.firewall   // ...ensure it remains after shutdown
	}
	
	/*
	 *  When the environment is first reloaded, it is responsible for re-constituting its own
	 *  node map so that it can use itself as a reference to the decoder.
	 */
	func reloadNodeMapFromCache() throws {
		let jd = JSONDecoder.standardRRDynamoDecoder(using: self)
		var nodeMap: RRNodeMap = .init()
		for (k, v) in config.nodeSnapshots {
			// ...these data snapshots are the only supported variants that 
			//    exist right after the configuration has been reloaded and
			//    do not contain opaque protocol references.
			guard case .data(let data, _) = v else { continue }
			let cRef   = try jd.decode(RRCRef<RRNode>.self, from: data)
			nodeMap[k] = cRef.ref
		}
		
		self.updateEnvironment { $0.state.replace(nodeMap: nodeMap) }
	}
	
	/*
	 *  Shut down the environment.
	 */
	func shutdown() async -> RRShutdownResult {
		guard let runtime = runtime.valueThenChanged(to: nil) else { return .failure(RRError.notProcessing) }
		self._operatingStatus = .shuttingDown
		let ret = await runtime.state.shutdown()
		self._operatingStatus = ret.isOk ? .offline : .failed
		return ret
	}
	
	/*
	 *  The object is destroyed.
	 */
	deinit {
		guard let runtime = runtime.valueThenChanged(to: nil) else { return }
		Task { let _ = await runtime.state.shutdown() }
	}

	private var _operatingStatus: RROperatingStatus 					  		= .running
	private var changeSubject: PassthroughSubject<ChangeType, Never> = .init()
	private var runtime: RRAtomic<Runtime?> 							  		= .init(nil)
	private var _cachedFW: RRFirewall!
}

/*
 *  Types.
 */
extension RREngineEnvironment {
	/*
	 *  Everything is organized under a single class to allow for transactional snapshots
	 *  that include both config and runtime.
	 */
	class Runtime {
		var config: RREngineConfig
		var state: RREngineState
		
		/*
		 *  Initialize the object.
		 */
		init(config: RREngineConfig, state: RREngineState) {
			self.config = config
			self.state = state
		}
	}
	
	// - changes to the environment are differentiated to avoid comparison checks.
	enum ChangeType {
		case enginePaused(_ value: Bool)
	}
	
	private var config: RREngineConfig {
		get { runtime.value?.config ?? .init(id: .init()) }
	}
	
	private var state: RREngineState {
		get {
			runtime.withLock {
				guard let ret = runtime.value?.state else {
					assert(false, "Unexpected post-shutdown state access.")
					return .init(with: self)
				}
				return ret
			}
		}
	}
	
	/*
	 *  Update the environment.
	 */
	private func updateEnvironment(with block:(_ runtime: Runtime) -> Void) {
		runtime.withLock {
			guard let d = runtime.value else { return }
			block(d)
		}
	}
}

/*
 *  Accessors.
 */
extension RREngineEnvironment {
	var log: Logger { self.state.log }	
	var isEnginePaused: Bool { self.state.isEnginePaused }
	
	/*
	 *  Pause all engine behavior..
	 */
	func setEnginePaused(_ isPaused: Bool) {
		self.updateEnvironment { runtime in
			guard runtime.state.isEnginePaused != isPaused else { return }
			runtime.state.isEnginePaused = isPaused
			self.notifyChanged(.enginePaused(isPaused))
		}
	}
	
	var firewall: RRFirewall { self._cachedFW }
	
	// - the repository identifier.
	var repositoryId: RRIdentifier { self.config.repositoryId }
	
	// - organized into a sub-environment to co-locate network-specific logic.
	var firewallContext: RRFirewallContext { self.state.fwContext }
	
	// - the engine snapshot is the basis for saving/loading the engine configuration and state.
	func snapshot() throws -> RREngineSnapshot {
		return try .init(config: self.config)
	}
	
	/*
	 *  Save a point-in-time copy of a dynamo.
	 */
	func saveDynamoSnapshot(_ dynamo: RRDynamoCodable) {
		let snapshot = RRDynamoCodableSnapshot(for: dynamo)
		self.updateEnvironment {
			$0.config.saveNodeSnapshot(snapshot)
		}
	}
	
	/*
	 *  Return a node by identifier.
	 */
	func node(for id: RRIdentifier) -> RRNode? { self.state.nodeMap[id] }

	/*
	 *  DEBUG:
	 *  Temporary function for verifying basic dynamo maintenance.
	 *  DEBUG:
	 */
	func debugAddHTTPPort() {
		updateEnvironment { $0.state.insert(RRDebugTriggerNode(in: self)) }
	}
}

/*
 *  Internal implementation.
 */
extension RREngineEnvironment {
	/*
	 *  This object implements its observability manually because not every action in the
	 *  engine necessarily warrants a change notification.
	 */
	private func notifyChanged(_ type: ChangeType) {
		self.changeSubject.send(type)
	}
}
