//
//  RRFirewallConnection.swift
//  RREngine
// 
//  Created on 9/1/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import NIOCore

/*
 *  DESIGN:  Firewall connections are a strict instance of communication between entities outside
 * 			 the firewall, through it, and into the internal network space.  These are not treated
 * 			 as part of the flow itself and only interface with it through an opaque data path into
 *			 the flow's trigger nodes.
 */

///  Manages a single external networking connection through the firewall.
///
@MainActor
public final class RRFirewallConnection : RRDynamo, Equatable {
	nonisolated public static func == (lhs: RRFirewallConnection, rhs: RRFirewallConnection) -> Bool { lhs.id == rhs.id }	
	override nonisolated class var logCategory: String? { "FirewallConnection" }
	
	/*
	 *  Create a new connection into a port and register it.
	 */
	nonisolated static func addHandler<C: RRFirewallPortController>(from owner: any RRFirewallPortRunnable, with controller: C, andChannel channel: Channel) -> EventLoopFuture<Void> {
		let promise = channel.eventLoop.makePromise(of: Void.self)
		
		// - hop over to the main thread to build the model.
		Task {
			await MainActor.run(body: {
				let conn    = RRFirewallConnection(from: owner, with: controller, andChannel: channel)
				let handler = RRFirewallConnectionHandler(withPortRuntime: owner, andConnectionRuntime: conn.runtime)
				owner.connectionWasCreated(conn)
				
				let runtime = conn.runtime as? C.Runtime
				
				// ...now hop back to the event loop to finish registration.
				let _ = channel.eventLoop.submit {
					// - add the protocol handler using the controller
					channel.pipeline.addHandler(handler).flatMap { _ in
						if let runtime = runtime {
							return controller.addChildHandler(from: runtime, channel: channel)
						}
						else {
							return channel.eventLoop.makeSucceededVoidFuture()
						}
					}
					.whenComplete { result in
						// - when everything else is done, complete the promise we made above.
						switch result {
						case .success():
							promise.succeed()
							
						case .failure(let err):
							self.log.error("Failed to add the handler to the channel pipeline.  \(err.localizedDescription, privacy: .public)")
							promise.fail(err)
						}
					}
				}
			})
		}
		return promise.futureResult
	}
	
	/*
	 *  Runtime state has changed.
	 */
	override func runtimeStateHasBeenUpdated() {
		super.runtimeStateHasBeenUpdated()
		
		// - keep the port in sync with the connection lifecycle
		if !(self.runtime?.isConnected ?? false) {
			owner?.connectionWasDisconnected(self)
		}
		
		// - when the metrics or connectivity changes, make sure the UI knows about it
		self.objectWillChange.send()
	}
		
	/*
	 *  Initialize the object.
	 */
	nonisolated private init(from owner: any RRFirewallPortRunnable, with controller: any RRFirewallPortController, andChannel channel: Channel) {
		self.owner 	 	     = owner
		self._channel.value  = channel
		self._remoteAddress = channel.remoteAddress?.asNetworkAddress()
		super.init(with: Config(controller: controller), in: owner.environment ?? .init())
	}
	
	// - internal
	private weak var owner: (any RRFirewallPortRunnable)?
	private let _remoteAddress: RRNetworkAddress?
	private let _channel: RRAtomic<Channel?> = .init(nil)
}

/*
 *  Utilities.
 */
extension SocketAddress {
	func asNetworkAddress() -> RRNetworkAddress? {
		if let ipAddr = self.ipAddress, let port = self.port {
			return .init(description: self.description, ipAddress: ipAddr, port: NetworkPortValue(port))
		}
		return nil
	}
}

/*
 *  Types
 */
extension RRFirewallConnection : RRActiveDynamoInternal {
	struct Config : RRDynamoConfigurable {
		var allowConnection: Bool

		let controller: any RRFirewallPortConnectable
		static func == (lhs: RRFirewallConnection.Config, rhs: RRFirewallConnection.Config) -> Bool {
			return lhs.allowConnection == rhs.allowConnection && lhs.controller.isEqualTo(other: rhs.controller)
		}
		init(controller: any RRFirewallPortConnectable) {
			self.allowConnection = true
			self.controller 	 = controller
		}
	}
	
	///  The operating behavior of the connection.
	public enum ConnectionStatus : String {
		///  The connection support I/O between client and server.
		case online
		
		///  The connection is being disconnected.
		case disconnecting
		
		///  The client/server communication is disconnected.
		case offline		
	}
	
	/*
	 *  Build the runtime.
	 */
	nonisolated func buildRuntime(with env: RREngineEnvironment?) -> RRFirewallConnectionRuntime? {
		guard let channel = _channel.value else { return nil }
		self._channel.value = nil
		
		// ...the channel is quickly passed onto the runtime where it is officially managed.
		return RRFirewallConnectionRuntime(with: self.config, environment: environment, channel: channel)
	}
}

/*
 *  Accessors.
 */
extension RRFirewallConnection {
	///  The protocol in used on the connnection.
	public var connectionType: RRNetworkProtocol { self.config.controller.portType }
	
	///  The remote network address of the connecdtion.
	public var remoteAddress: RRNetworkAddress { self._remoteAddress ?? .init(description: "no-connection", ipAddress: "127.0.0.1", port: 0) }
	
	///  The operating status of the connection
	public var connectionStatus: ConnectionStatus {
		if self.runtime?.isConnected ?? false {
			return self.config.allowConnection ? .online : .disconnecting
		}
		else {
			return .offline
		}
	}
	
	///  The statistics for network traffic on this connection.
	public var networkMetrics: RRNetworkMetrics { runtime?.networkMetrics ?? .init() }

	///  Disconnect the client/server connection.
	public func disconnect() {
		// - communicate to the runtime through the confguration, which will
		//   then initiate an orderly disconnection
		self.config.allowConnection = false
	}
}
