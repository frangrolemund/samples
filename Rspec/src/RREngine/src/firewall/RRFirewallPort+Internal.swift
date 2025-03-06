//
//  RRFirewallPort+Internal.swift
//  RREngine
// 
//  Created on 8/25/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import NIOCore

// - common configuration requirements for all ports.
protocol RRFirewallPortConfigurable : RRDynamoConfigurable, RRIdentifiable {
	associatedtype Controller: RRFirewallPortController where Controller.Config == Self
	static var controllerType: Controller.Type { get }
	
	init()
	
	// - required configuration
	var portType: RRNetworkProtocol { get }	
	var isEnabled: Bool { get set }
	var value: NetworkPortValue? { get set }
	var defaultValue: NetworkPortValue? { get }
	var clientBacklog: UInt16 { get set }
	
	// - custom formatting
	var targetURL: URL? { get }
}
extension RRFirewallPortConfigurable {
	static var DefaultClientBacklog: UInt16 { 4 }
	
	// - convenience accessorn for common controller type.
	var controllerType: Controller.Type { Self.controllerType }

	// - create a controller for ports of this type.
	func buildController() -> Controller { controllerType.init(with: self) }
	
	// - the creation defaults are intended to ensure that a port never
	//   comes online automatically, but must be authorized first by the
	//   caller of the engine.
	func withPortCreationDefaults() -> Self {
		var ret   		  		   = self
		ret.isEnabled			   = true
		ret.value 		  		   = nil
		return ret
	}
}

/*
 *  Consistent network metrics handling.
 */
protocol RRFirewallPortNetworkMetricsCapable : AnyObject {
	func notifyNetworkTrafficMetrics(_ metricUpdates: RRNetworkMetrics) async
}

/*
 *  Generic firewall port runtime accessors.
 */
protocol RRFirewallPortRunnable : RRActiveDynamoRunnable, RRFirewallPortNetworkMetricsCapable {
	nonisolated var isFirewallEnabled: Bool { get set }
	nonisolated var portStatus: RRFirewallPort.PortStatus { get }
	nonisolated var portMetrics: RRFirewallPort.PortMetrics { get }
	nonisolated var connections: [RRFirewallConnection] { get }

	nonisolated func connectionWasCreated(_ connection: RRFirewallConnection)
	nonisolated func connectionWasDisconnected(_ connection: RRFirewallConnection)
}

/*
 *  Connectable entities provide opaque logic for managing
 *  network accesses of the port.
 *  DESIGN:  This is 'Sendable' and not an object because I think
 *  	     it is best if the controller not be encouraged to
 *  		 store unique state and simply operate as a type of
 * 			 delegate for networking.  This also plays well into
 * 			 the RRFirewallConnection treating connectable instances
 * 			 as configuration.
 */
protocol RRFirewallPortConnectable : Sendable, Equatable {
	var portType: RRNetworkProtocol { get }
	
	//  TODO: These will be general purpose methods used by the RRFiber to abort gradually, I think.  (see 9/5/23, 9/8/23)
}
extension RRFirewallPortConnectable {
	func isEqualTo(other: any RRFirewallPortConnectable) -> Bool {
		guard let other = other as? Self else { return false }
		return self == other
	}
}

/*
 *  The controller provides the custom logic to configure and manage specialized
 *  protocol variants of each port connection, which gets a dedicated controller
 *  instance.
 */
protocol RRFirewallPortController : RRFirewallPortConnectable {
	associatedtype Config: RRFirewallPortConfigurable
	associatedtype Runtime: RRFirewallConnectionRuntime
	
	var config: Config { get }

	init(with config: Config)
	func addChildHandler(from runtime: Runtime, channel: Channel) -> EventLoopFuture<Void>
}
extension RRFirewallPortController {
	var portType: RRNetworkProtocol { config.portType }
}

/*
 *  Firewall port implementations.
 */
protocol RRFirewallPortInternal : RRFirewallPort, RRActiveDynamoInternal where Config: RRFirewallPortConfigurable, Runtime == RRFirewallPortRuntime<Config, Config.Controller> {}
extension RRFirewallPortInternal {
	/*
	 *  Firewall ports use a general purpose runtime that manages most of the connectivity
	 *  and reconfiguration behavior while deferring some minor elements to a controller that
	 *  is built from its configuration type.
	 */
	nonisolated func buildRuntime(with env: RREngineEnvironment?) -> Runtime? {
		guard let _ = firewall, let fwContext = env?.firewallContext else { return nil }
		return RRFirewallPortRuntime(asPort: self, withConfig: self.config, inFirewallContext: fwContext)
	}
}
