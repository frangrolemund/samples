//
//  RRFirewallPort+Runtime.swift
//  RREngine
// 
//  Created on 8/25/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog
import Combine
import NIOCore
import NIOPosix

/*
 *  Manages general-purpose connnectivity for a firewall port.
 */
class RRFirewallPortRuntime<Config: RRFirewallPortConfigurable, Controller: RRFirewallPortController> :
	RRDynamoRuntime<Config, RRFirewallPortRuntime.State> where Config == Controller.Config {
	
	/*
	 *  Build the runtime state.
	 */
	override func buildRuntimeState() -> State {
		return .init(with: self.__context as? RRFirewallPort)
	}

	/*
 	 *  Initialize the object.
 	 */
 	init(asPort port: RRFirewallPort, withConfig config: Config, inFirewallContext context: RRFirewallContext) {
		// ...not this runtime's context, but the firewall context.
		self.fwContext = context
		
		// ...pass the port temporarily in the general runtime context
		//    so that the state can be initialized, then discard it.
		super.init(with: port.environment, config: Config(), context: port)
		self.__context = nil
 	}
	
	/*
	 *  The configuration has been changed.
	 */
	override func configurationHasChanged() {
		super.configurationHasChanged()
		_configurationHasChanged()
	}
	
	/*
	 *  The runtime has been paused/unpaused.
	 */
	override func pausedStatusWasUpdated() async {
		await super.pausedStatusWasUpdated()
		
		//  DESIGN: The port *must* be offlined if it is paused becasue the intent of pausing
		// 			is to support non-conflicting port assignments in multiple engine copies
		//			which would not be possible if any of them are actually configured in the
		//			networking subsystem.
		_configurationHasChanged()
	}
	
	/*
	 *  Shut down the runtime.
	 */
	override func shutdown(with config: Config, andContext context: Any?) async -> RRShutdownResult {
		var ret: RRShutdownResult = .success
		
		for c in self.state?.connections ?? [] {
			ret.append(await c.shutdown())
		}
		self.state?.connections = []
		
		await stopServer(from: config)

		return ret
	}
	
	// - internal
	private let fwContext: RRFirewallContext
}

/*
 *  Types
 */
extension RRFirewallPortRuntime {
	/*
	 *  The state of the port tracks its statistics and active connections.
	 *  DESIGN:  It is a reference type so that it can save a weak reference to
	 * 			 the owner.
	 */
	struct State : RRDynamoRuntimeStateful {
		weak var owner: RRFirewallPort?
		var cTask: Task<Void, Never>?
		var serverChannel: Channel?
		
		var inReconfig: Bool
		var isFirewallEnabledOverride: Bool
		var portStatus: RRFirewallPort.PortStatus {
			didSet { self.inReconfig = false }
		}
		var portMetrics: RRFirewallPort.PortMetrics
		var connections: [RRFirewallConnection]
		var activeConfig: PortConfigSnapshot?
		
		/*
		 *  Initialize the object.
		 */
		init(with owner: RRFirewallPort? = nil) {
			self.owner		  	   		   = owner
			self.inReconfig   	   		   = false
			self.isFirewallEnabledOverride = owner?.firewall?.isEnabled ?? false
			self.portStatus   	   		   = .offline
			self.portMetrics  	   		   = .init()
			self.connections  	   		   = []
			self.activeConfig 	  		   = nil
		}
		
		// - the configuration snapshot is important because it offers quick
		//   determination of whether anything has changed that would influence
		//   the port behavior.
		struct PortConfigSnapshot : Equatable {
			let isFirewallEnabled: Bool
			let model: Config
			let isPaused: Bool
			
			// - initialize the snapshot
			init(with port: RRFirewallPort?, isFirewallEnabledOverride: Bool, andConfig config: Config, asPaused isPaused: Bool) {
				self.isFirewallEnabled = port?.firewall?.isEnabled ?? isFirewallEnabledOverride
				self.model	  		   = config
				self.isPaused		   = isPaused
			}
			
			// ... convenience for whether we expect it to be online.
			var isOnline: Bool { !self.isPaused && self.isFirewallEnabled && self.model.isEnabled && self.model.value != nil }
		}
	}
}

/*
 *  Accessors
 */
extension RRFirewallPortRuntime : RRFirewallPortRunnable {	
	private var owner: RRFirewallPort? { self.state?.owner }
	
	// - the firewall can choose to enable/disable all the ports independently of their own configurations stating otherwise.
	 var isFirewallEnabled: Bool {
		 get { self.state?.activeConfig?.isFirewallEnabled ?? false }
		 set { _changeFirewallEnabledState(isEnabled:newValue) }
	}
	
	// - change the enabled state
	private func _changeFirewallEnabledState( isEnabled: Bool) {
		guard isEnabled != self.isFirewallEnabled else { return }
		self.state?.isFirewallEnabledOverride = isEnabled
		configurationHasChanged()
	}
		
	// - the networking status of the port
	nonisolated var portStatus: RRFirewallPort.PortStatus {
		return withStateIfRunning { state in
			if state.inReconfig {
				return .reconfiguring
			}
			return state.portStatus
		} ?? .offline
	}
	
	// - the runtime statistics of traffic through the port
	nonisolated var portMetrics: RRFirewallPort.PortMetrics { self.state?.portMetrics ?? .init() }
	
	// - the active connections.
	nonisolated var connections: [RRFirewallConnection] { self.state?.connections ?? [] }
}

/*
 *  Internal implementation.
 */
extension RRFirewallPortRuntime {
	private static var ReconfigurationDelay: Duration { .milliseconds(200) }
	private var log: Logger { self.fwContext.log }
	
	/*
	 *  A connection was formed with a client.
	 */
	nonisolated func connectionWasCreated(_ connection: RRFirewallConnection) {
		self.withStateIfRunning { state in
			guard state.connections.firstIndex(where: {$0.id == connection.id }) == nil else { return }
			state.connections.append(connection)
		}
	}
	
	/*
	 *  Detect modifications in state based on configuration.
	 */
	private func _configurationHasChanged() {
		self.state?.cTask?.cancel()
		withStateIfRunning { state in
			state.cTask = Task {
				// ...sleep briefly
				try? await Task.sleep(for: Self.ReconfigurationDelay)
				guard !Task.isCancelled else { return }
				await rebuildPortForNewConfiguration()
			}
		}
	}
	
	/*
	 *  A connection was severed.
	 */
	nonisolated func connectionWasDisconnected(_ connection: RRFirewallConnection) {
		withStateIfRunning { state in
			guard let idx = state.connections.firstIndex(where: {$0.id == connection.id}) else { return }
			let conn = state.connections.remove(at: idx)
			Task { let _ = await conn.shutdown() }
		}
	}
	
	/*
	 *  Apply the current configuration to modifying the port.
	 */
	private func rebuildPortForNewConfiguration() async {
		// ...it is possible that this rebuilding could be in progress when
		//    new requests are received.  Assume the later loop will apply the changes.
		guard let canRebuild = withStateIfRunning({ (state) -> Bool in
			guard !state.inReconfig else { return false }
			state.inReconfig = true
			return true
		}), canRebuild else { return }
		
		// - only one instance of this reconfiguration sequence will be running regardless
		//   of whether requests make it into this actor while it is blocked on startup.)
		while true {
			let newConfig = State.PortConfigSnapshot(with: self.state?.owner,
													 isFirewallEnabledOverride: self.state?.isFirewallEnabledOverride ?? false,
													 andConfig: self.config,
													 asPaused: self.isPaused)
			guard let _ = self.state, self.state?.activeConfig != newConfig else { break }
			
			logStartRebuild(from: self.state?.activeConfig, to: newConfig)
			
			// ...first stop the existing server
			if let activeConfig = self.state?.activeConfig, let _ = self.state?.serverChannel {
				await self.stopServer(from: activeConfig.model)
			}
			
			// ...now start a new server.
			if newConfig.isOnline {
				await self.startServer(from: newConfig.model)
			}
			
			logCompleteRebuild(from: self.state?.activeConfig, to: newConfig)
			self.state?.activeConfig = newConfig
		}
		
		// - rebuild completed
		self.state?.inReconfig = false
	}
	
	/*
	 *  Logging when starting a port reconfiguration.
	 */
	private func logStartRebuild(from fromConfig: State.PortConfigSnapshot?, to toConfig: State.PortConfigSnapshot) {
		let wasOnline = (fromConfig?.isOnline ?? false) && self.portStatus == .online
		guard wasOnline || toConfig.isOnline else { return }
				
		let changeType: String = toConfig.isPaused ? "Pausing" : (toConfig.isOnline ? (wasOnline ? "Reconfiguring" : "Enabling") : "Disabling")
		self.log.notice("\(changeType, privacy: .public) \(toConfig.model.portType.description, privacy: .public) port \(toConfig.model.id.briefId, privacy: .public)\(toConfig.isOnline ? " with new configuration." : ".", privacy: .public)")

	}
	
	/*
	 *  Logging when completing a port reconfiguration.
	 */
	private func logCompleteRebuild(from fromConfig: State.PortConfigSnapshot?, to toConfig: State.PortConfigSnapshot) {
		let wasOnline = (fromConfig?.isOnline ?? false)
		guard wasOnline || toConfig.isOnline else { return }
	
		let logPrefix = "The \(toConfig.model.portType.description) port \(toConfig.model.id.briefId)"
		let status 	  = self.portStatus
		if case .error(let err) = status {
			self.log.error("\(logPrefix, privacy: .public) failed reconfiguration.  \(err.localizedDescription, privacy: .public)")
		}
		else if status == .online, let tURL = toConfig.model.targetURL {
			self.log.info("\(logPrefix, privacy: .public) is online as \(tURL.absoluteString, privacy: .public)")
		}
		else {
			self.log.info("\(logPrefix, privacy: .public) \(self.portStatus.description, privacy: .public).")
		}
	}
	
	/*
	 *  Create a server instance using the configuration.
	 */
	private func startServer(from newConfig: Config) async -> Void {
		guard let portValue = newConfig.value else {
			assert(self.state?.serverChannel != nil, "Unexpected active channel.")
			return
		}

		self.state?.portStatus = .starting
		
		// - everything in the child channel is managed by the connection, including
		//   the protocol configuration defined by the controller.
		@Sendable func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
			guard let rt = owner?.__runtime as? (any RRFirewallPortRunnable) else { return channel.eventLoop.makeSucceededVoidFuture() }
			return RRFirewallConnection.addHandler(from: rt, with: self.config.buildController(), andChannel: channel)
		}
		
		let ret	= await self.fwContext.bootstrapServer(toPort: portValue) { bootstrap in
			bootstrap.serverChannelOption(ChannelOptions.backlog, value: ChannelOptions.Types.BacklogOption.Value(newConfig.clientBacklog))
				.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
				.childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
				.childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
				.childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: false)		// - this isn't useful for this purpose.
				.childChannelInitializer(childChannelInitializer(channel:))
		}

		withStateIfRunning { state in
			switch ret {
			case .success(let channel):
				state.serverChannel = channel
				state.portStatus    = .online
				
			case .failure(let err):
				state.portStatus 	= .error(err)
			}
		}
	}
	
	/*
	 *  Stop the server.
	 */
	private func stopServer(from oldConfig: Config) async -> Void {
		guard let serverChannel = withStateIfRunning({ (state) -> Channel? in
			guard let sc = state.serverChannel else { return nil }
			state.portStatus    = .stopping
			state.serverChannel = nil
			return sc
		}) else { return }
		
		// ...NIO channels won't shut down until all of their clients are disconnected.
		for conn in self.state?.connections ?? [] {
			await conn.shutdown()
		}
		
		// ...close the server finally.
		serverChannel.close(promise: nil)
		do {
			try await serverChannel.closeFuture.get()
		}
		catch {
			// - this could result in a leaked channel, which I'm going to monitor for
			//   how often this occurs in practice.
			assert(false, "Unexpected failure to stop channel.")
			self.log.error("Failed to stop the port \(oldConfig.id.briefId, privacy: .public) listening on \(oldConfig.targetURL?.absoluteString ?? "n/a", privacy: .public).  \(error.localizedDescription, privacy: .public)")
		}
		
		self.state?.portStatus = .offline
	}
	
	/*
	 *  Data has passed through the port.
	 */
	func notifyNetworkTrafficMetrics(_ metricUpdates: RRNetworkMetrics) {
		withStateIfRunning { state in
			state.portMetrics.networkMetrics += metricUpdates
		}
	}
}
