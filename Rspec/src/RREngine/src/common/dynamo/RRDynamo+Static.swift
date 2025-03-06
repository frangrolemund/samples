//
//  RRDynamo+Static.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine

/*
 *  A static dynamo exposes only configuration and state, but performs no processing of its own.
 */
@MainActor
protocol RRStaticDynamoInternal : RRDynamoInternal {
	associatedtype Config : RRDynamoConfigurable
	associatedtype State: RRStaticDynamoStateful
	associatedtype Runtime: RRDynamoStatefulManager where Runtime == RRStaticDynamoRuntime<State>
	
	nonisolated func buildState() -> State
}

@MainActor
extension RRStaticDynamoInternal {
	nonisolated func __buildRuntime(with env: RREngineEnvironment?) -> (any RRDynamoStatefulManager)? { Runtime(with: self.buildState() ) }
	
	nonisolated var config: Config {
		get { self.__config as! Config }
		set { self.__config = newValue }
	}
	nonisolated static var codableConfigurationType: (any RRDynamoCodableConfigurable.Type)? { Config.self as? any RRDynamoCodableConfigurable.Type }
	
	nonisolated var runtime: Runtime? {
		get { self.__runtime as? Runtime }
		set { self.__runtime = newValue }
	}
	
	nonisolated var state: State? {
		get { self.runtime?.state }
		set {
			guard let newValue = newValue else { return }
			self.runtime?.state = newValue
		}
	}
}

/*
 *  Static dynamos assume state is in a single entity (usually a structure)
 *  and it performs some amount of rudimentary shutdown in place of the
 *  shutdown normally provided by a custom runtime implementation.
 */
protocol RRStaticDynamoStateful : Sendable, RRStatefulProcessor {
}
extension RRStaticDynamoStateful {
	func shutdown() async -> RRShutdownResult { .success }
}

/*
 *  The generial purpose non-processing runtime for static dynamos.
 */
struct RRStaticDynamoRuntime<S: RRStaticDynamoStateful> : RRDynamoStatefulManager {
	/*
	 *  Initialize the entity.
	 */
	init(with state: S) {
		self.data = .init(.init(state: state, status: .running))
	}
	
	nonisolated var state: S {
		get { self.data.value.state }
		set {
			self.data.value.state = newValue
		}
	}
	
	nonisolated var status: RROperatingStatus { self.data.value.status }
	nonisolated var statefulPublisher: RRDynamoRuntimePublisher { self.data.objectWillChange.map({ _ in self }).eraseToAnyPublisher() }
	
	/*
	 *  Shut down the dynamo.
	 */
	func shutdown() async -> RRShutdownResult {
		guard status == .running else { return .failure(RRError.notProcessing) }
		self.data.value.status = .shuttingDown
		let ret  = await self.data.value.state.shutdown()
		self.data.value.status = ret.isOk ? .offline : .failed
		return ret
	}
	
	private let data: RRAtomic<Data>
	private struct Data {
		var state: S
		var status: RROperatingStatus
	}
}
