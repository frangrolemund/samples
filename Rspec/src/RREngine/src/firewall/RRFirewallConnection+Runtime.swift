//
//  RRFirewallConnection+Runtime.swift
//  RREngine
// 
//  Created on 9/1/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine
import NIOCore

/*
 *  The runtime for a firewall connection.
 */
class RRFirewallConnectionRuntime : RRDynamoRuntime<RRFirewallConnection.Config, RRFirewallConnectionRuntime.State>, RRFirewallPortNetworkMetricsCapable, RRLoggableCategory {
	static var logCategory: String? { "FirewallConnection" }
	
	/*
	 *  Generate the state.
	 */
	override func buildRuntimeState() -> State {
		assert(self.__context as? Channel != nil, "Unexpected missing context.")
		return .init(channel: self.__context as? Channel)
	}

	/*
	 *  Initialize the runtime.
	 */
	init(with config: Config, environment: RREngineEnvironment?, channel: Channel) {
		// ...briefly use the context for initializing the state, then reset that reference.
		super.init(with: environment, config: config, context: channel)
		self.__context = nil
	}
	
	/*
	 *  The configuration was modified.
	 */
	override func configurationHasChanged() {
		guard !config.allowConnection else { return }
		Task { await self.abortConnection() }
	}
	
	/*
	 *  The connection was paused.
	 */
	override func pausedStatusWasUpdated() async {
		//  DESIGN: Connections cannot exist in a paused state because the
		//  		networking stack doesn't differentiate such things and
		//			to allow it would invite conflicts between two instances
		// 	 		of the same engine.
		guard isPaused else { return }
		await self.abortConnection()
	}
	
	/*
	 *  Shut down the connection.
	 */
	override func shutdown(with config: RRFirewallConnection.Config, andContext context: Any?) async -> RRShutdownResult {
		if self.state?.isConnected ?? false {
			let nAddr = self.state?.channel?.remoteAddress?.asNetworkAddress()
			self.log.notice("Aborting active connection\(nAddr != nil ? " to \(nAddr!.description)" : "", privacy: .public).")
		}
		return await self.abortConnection()
	}
	
	private var tDisconnect: Task<RRShutdownResult, Never>?
}

/*
 *  Types
 */
extension RRFirewallConnectionRuntime {
	struct State : RRDynamoRuntimeStateful {
		var isConnected: Bool
		let channel: Channel?
		var metrics: RRNetworkMetrics
		
		init(channel: Channel?) {
			isConnected  = true
			self.channel = channel
			self.metrics = .init()
		}
	}
}

/*
 *  Internal
 *  DESIGN:  Notification methods are used by the connection handlers to route data from that
 *  		 concurrency domain to the model.  By updating the transient state, the dynamo's
 *  		 runtimeStateHasBeenUpdated() method will be called, which is a good place for
 * 	 		 the model to respond to this more formally.
 */
extension RRFirewallConnectionRuntime {
	nonisolated var isConnected: Bool { self.state?.isConnected ?? false }
	nonisolated var networkMetrics: RRNetworkMetrics { self.state?.metrics ?? .init() }
	
	/*
	 *  Notify the model of its disconnected status.
	 *  - this method gives the handler a very quick way to ensure the model
	 *    is aware of the disconnect and can notify the port so the connection can
	 *    be removed from consideration.
	 */
	func notifyDisconnected() {
		self.state?.isConnected = false
	}
	
	/*
	 *  Data has passed on the connection.
	 */
	func notifyNetworkTrafficMetrics(_ metricUpdates: RRNetworkMetrics) {
		withStateIfRunning { state in
			state.metrics += metricUpdates
		}
	}
	
	/*
	 *  Initiate an orderly disconnection.
	 */
	@discardableResult private func abortConnection() async -> RRShutdownResult {
		if let tD = tDisconnect {
			return await tD.value
		}
		
		//  DESIGN: I've given some thought to whether this process should begin with
		// 			a protocol-oriented abort before forcibly severing the connection
		// 			and decided that for _almost every case_ the expectation must be
		// 		    that the connection is severed without response.  Many times, this
		// 	 		is used to disconnect during a reconfiguration of a port and the
		//			hanging connection will just be rebuilt on the next request.  The
		//			*only* special scenario is when aborting a fiber, which is not
		//			connection-oriented, but protocol-oriented and will be handled
		//			differently when it is aborted by itself outside the connection.
				
		guard let channel = self.state?.channel, channel.isActive else { return .success }
		let ret: Task<RRShutdownResult, Never> = Task {
			return await withUnsafeContinuation({ continuation in
				channel.eventLoop.execute {
					// - the bridge back into swift-concurrency will occur when all
					//   promises are fulfilled.
					let promise = channel.eventLoop.makePromise(of: Void.self)
					promise.futureResult.whenComplete { result in
						switch result {
						case .success():
							continuation.resume(returning: .success)
							
						case .failure(let err):
							self.log.error("Connection shutdown has failed.  \(err.localizedDescription, privacy: .public)")
							continuation.resume(returning: .failure(err))
						}
					}
					
					// - close the channel
					channel.close(promise: promise)
				}
			}) as RRShutdownResult
		}
		self.tDisconnect = ret
		return await ret.value
	}
}
