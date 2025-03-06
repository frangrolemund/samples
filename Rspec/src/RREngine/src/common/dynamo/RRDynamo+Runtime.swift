//
//  RRDynamo+Runtime.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine

/*
 *  The manager ts the _stateful_ storage of the dynamo, incorporating transient
 *  changes as it performs its operations.  All requests for state are always made
 *  of the manager.  When the dynamo shuts down, its managert is detached and
 *  unavailable for accesses.
 */
protocol RRDynamoStatefulManager : RRStatefulProcessor {
	nonisolated var statefulPublisher: RRDynamoRuntimePublisher { get }
}
typealias RRDynamoRuntimePublisher = AnyPublisher<any RRDynamoStatefulManager, Never>

/*
 *  Most dynamos benefit from background processing, which is better managed by
 *  a dedicated object that maintains its own isolation context.
 */
protocol RRActiveDynamoRunnable : AnyObject, RRDynamoStatefulManager {
	// - the configuration is defined and owned by the model to
	//   keep it close to where it is managed.
	associatedtype Config: RRDynamoConfigurable
	
	var environment: RREngineEnvironment? { get }
	
	// - incorporate changes to the configuration managed by the model
	// DESIGN:  Regardless of how you init() your runtime, you should _only_ react to
	//  		configuration changes to perform processing in response to this method
	//		    because it will be consistently invoked by the dynamo when first initialized.
	func apply(_ config: Config) async
	
	// - pause/unpause the runtime.
	// DESIGN: This is important because the actor is independent of the model and isn't
	//         expected to subscribe to the environment.
	func pause(_ isPaused: Bool) async
}

/*
 *  The operating state data for runtimes (active dynamos).
 */
protocol RRDynamoRuntimeStateful : Sendable {
}

extension Bool : RRDynamoRuntimeStateful {}
extension Int : RRDynamoRuntimeStateful {}
extension String : RRDynamoRuntimeStateful {}
extension Float : RRDynamoRuntimeStateful {}

/*
 *  Most dynamos benefit from background processing, which is better managed
 *  by a dedicated entity with clear asynchronous access paths in its own
 *  isolation context.
 *  DESIGN:  This was originally an Actor, but the need for nonisolated paths
 *  		 during init and for state accesses along with common processing that
 *  		 couldn't be pushed into inheritance largely negated the advantages of
 * 	 		 the entity.  This is intended to be simpler and less redundant for
 * 	 		 most scenarios.
 */
class RRDynamoRuntime<Config: RRDynamoConfigurable, State: RRDynamoRuntimeStateful> : RRActiveDynamoRunnable {
	var environment: RREngineEnvironment? { __env.value }
	var statefulPublisher: RRDynamoRuntimePublisher {self.__state.objectWillChange.map({_ in self }).eraseToAnyPublisher()}
	
	/*
	 *  Initialize the object.
	 *  - the 'context' is an optional runtime-specific configuration that can be safely managed under lock.
	 */
	init(with environment: RREngineEnvironment?, config: Config, context: Any? = nil) {
		self.__env   = .init(environment)
		self.__state = .init(nil)
		self.__data  = .init(.init(isPaused: environment?.isEnginePaused ?? false, config: config, context: context))
		self.state   = self.buildRuntimeState()
	}
	
	/*
	 *  Create a new state value instance using the runtime configuration if desired.
	 *  DESIGN: I'm using an instance method to maintain parity with the dynamo `buildRuntime` approach.
	 */
	func buildRuntimeState() -> State {
		assert(false, "State initialization is required.")
		fatalError()
	}
	
	/*
	 *  Receives updated configuration from the owning dynamo.
	 */
	final func apply(_ config: Config) async {
		self.__data.value.config = config
		configurationHasChanged()
	}
	
	/*
	 *  The runtime configuration has been modified by the owning dynamo.
	 */
	func configurationHasChanged() {
	}
	
	/*
	 *  Change the paused status of the dynamo.
	 */
	final func pause(_ isPaused: Bool) async {
		self.__data.value.isPaused = isPaused
		await pausedStatusWasUpdated()
	}
	
	/*
	 *  The runtime was paused/unpaused.
	 */
	func pausedStatusWasUpdated() async {
	}
	
	/*
	 *  Halt all further opertions in the dynamo.
	 */
	final func shutdown() async -> RRShutdownResult {
		// - NOTE: I preferred to not reset the state until after shutdown so that the
		//         implementation can use its standard accessors without modification.
		guard let _ = __state.value else { return .failure(RRError.notProcessing) }
		let ret = await shutdown(with: self.config, andContext: __context)
		__state.value = nil
		return ret
	}
	
	/*
	 *  Shut down the runtime.
	 */
	func shutdown(with config: Config, andContext context: Any?) async -> RRShutdownResult {
		return .success
	}

	private let __env: RRWeakAtomic<RREngineEnvironment>
	private let __data: RRAtomic<Data>
	private let __state: RRAtomic<State?>
}

/*
 *  Types
 */
extension RRDynamoRuntime {
	/*
	 *  Configuration data for the runtime.
	 */
	private struct Data {
		var isPaused: Bool
		var config: Config
		var context: Any?
	}
}

/*
 *  Accessors.
 */
extension RRDynamoRuntime {
	// - whether the runtime is currently paused
	var isPaused: Bool { __data.value.isPaused }
	
	// - the dynamo configuration provided to the runtime.
	var config: Config { __data.value.config }
	
	var state: State? {
		get { self.__state.value }
		set { self.__state.value = newValue }
	}
	
	/*
	 *  Access the state under lock.
	 */
	func withStateIfRunning<R>(_ block: (_ state: inout State) -> R?) -> R? {
		return __state.withLock {
			guard var state = __state.value else { return nil }
			let ret = block(&state)
			__state.value = state
			return ret
		}
	}
		
	// - the custom configuration for the runtime.
	var __context: Any? {
		get { __data.value.context }
		set { __data.value.context = newValue }
	}
	
	/*
	 *  Access the context under lock.
	 */
	func __withContext(_ block: (_ value: inout Any?)-> Void) {
		__data.withLock {
			var ctx = __data.value.context
			block(&ctx)
			__data.value.context = ctx
		}
	}
}
