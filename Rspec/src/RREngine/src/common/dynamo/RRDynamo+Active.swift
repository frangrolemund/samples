//
//  RRDynamo+Internal.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  An active dynamo is one with a processing runtime entity.
 */
@MainActor
protocol RRActiveDynamoInternal : RRDynamoInternal {
	associatedtype Config : RRDynamoConfigurable
	associatedtype Runtime: RRActiveDynamoRunnable where Runtime.Config == Config
	
	// - internal implementations must create their own runtime.
	nonisolated func buildRuntime(with env: RREngineEnvironment?) -> Runtime?
}

extension RRActiveDynamoInternal {
	nonisolated var config: Config {
		get { self.__config as! Config }
		set { self.__config = newValue }
	}
	nonisolated static var codableConfigurationType: (any RRDynamoCodableConfigurable.Type)? { Config.self as? any RRDynamoCodableConfigurable.Type }
	
	nonisolated var runtime: Runtime? {
		get { self.__runtime as? Runtime }
	}
	
	// - used only by initialization.
	nonisolated func __buildRuntime(with env: RREngineEnvironment?) -> (any RRDynamoStatefulManager)? { buildRuntime(with: env) }
	
	// - used only during model updates
	nonisolated func __applyConfigToRuntime() { Task { await self.runtime?.apply(self.config) } }
	
	// - used to pause/unpause the processing
	nonisolated func __setPaused(_ isPaused: Bool) { Task { await self.runtime?.pause(isPaused) } }
}
