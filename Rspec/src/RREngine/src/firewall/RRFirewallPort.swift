//
//  RRFirewallPort.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine

/*
 *  DESIGN:  This class has public exports, but is not intended to ever be directly created
 *  		 either internally or extrenally and only serves as a common base to which all
 *           ports conform.
 */

///  Manages a local network-accessible protocol ingress for the engine.
///
@MainActor
public class RRFirewallPort : RRDynamo {
	/// The active network connections to the port.
	public private (set) var connections: [RRFirewallConnection] = []
	
	/*
	 *  Initialize the object.
	 */
	nonisolated init(withFirewall firewall: RRFirewall, andConfig config: any RRFirewallPortConfigurable) {
		self._firewall = .init(firewall)
		
		// - the act of initializing the base will buildRuntime() in the port and
		//   generate the controller, which can draw upon the configuration if desired.
		super.init(with: config, in: firewall.environment, identifier: config.id)
		
		// - detect changes to the firewall configuration itself to inform this port's behavior.
		self.fwSub = firewall.objectWillChange.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
			self?.runtime?.isFirewallEnabled = self?.firewall?.isEnabled ?? false
		})
	}
	
	/*
	 *  The runtime state has changed.
	 */
	override func runtimeStateHasBeenUpdated() {
		super.runtimeStateHasBeenUpdated()
		
		// - cache the port status so we know when it changes.
		if self.lastPortStatus != self.portStatus {
			self.lastPortStatus = self.portStatus
			self.runtimeStateWillChangeModel()
			
			// - because the firewall uses the port statuses for its own
			//   model, we should reflect this change there.
			self.firewall?.runtimeStateWillChangeModel()
		}

		// - to ensure the shutdown process occurs reliably, the connections are saved
		//   in the runtime as state, but cached here for efficient model access.
		if let curConn = self.runtime?.connections, curConn != self.connections {
			self.runtimeStateWillChangeModel()
			self.connections = curConn
		}
	}
		
	/*
	 *  Shut down the port.
	 */
	override func shutdown() async -> RRShutdownResult {
		fwSub?.cancel()
		return await super.shutdown()
	}
	
	nonisolated internal var firewall: RRFirewall? { _firewall.value }
	private let _firewall: RRWeakAtomic<RRFirewall>
	private var fwSub: AnyCancellable?
	private var lastPortStatus: PortStatus?
}

/*
 *  Types
 */
extension RRFirewallPort {
	/// Describes the operating capability of a port for inbound or outbound network traffic.
	public enum PortStatus : Sendable, Equatable, CustomStringConvertible {
		///  Compare two port statuses for equality.
		public static func == (lhs: RRFirewallPort.PortStatus, rhs: RRFirewallPort.PortStatus) -> Bool { lhs.description == rhs.description }
		
		/// The entity is disabled and will not pass traffic.
		case offline
		
		/// The entity is preparing to be online.
		case starting
		
		/// The entity is enabled and may pass traffic.
		case online
		
		/// The entity is enabled, but only partially and likely affecting throughput or protocol support.
		case degraded
		
		/// The entity is preparing to be offline.
		case stopping
		
		/// The entity is being reconfigured.
		case reconfiguring
		
		/// The entity is disabled because an error is preventing its operation.
		case error(_ value: Error)
		
		/// A textual description of the port status.
		public var description: String {
			switch self {
			case .offline:
				return "offline"
				
			case .starting:
				return "starting"
				
			case .online:
				return "online"
				
			case .degraded:
				return "degraded"
				
			case .stopping:
				return "stopping"
				
			case .reconfiguring:
				return "reconfiguring"
				
			case .error(let err):
				return "failed: \(err.localizedDescription)"
			}
		}
		
		/// Indicates the port is not in the process of reconfiguration.
		var isTerminal: Bool {
			if case .error(_) = self { return true }
			return (self == .online || self == .offline)
		}
	}
	
	/// Describes statistics of port operation.
	public struct PortMetrics : Sendable {
		/// The I/O metrics for the port.
		public var networkMetrics: RRNetworkMetrics
		
		/// Initialize the object.
		public init() {
			self.networkMetrics = .init()
		}
	}		
}

/*
 *  Accessors.
 */
extension RRFirewallPort {
	private var config: any RRFirewallPortConfigurable {
		get { self.__config as! (any RRFirewallPortConfigurable) }
		set { self.__config = newValue }
	}
	nonisolated internal var runtime: (any RRFirewallPortRunnable)? { self.__runtime as? any RRFirewallPortRunnable }
	
	/// The name of the node which owns the port.
	public var name: String? { environment.node(for: self.id)?.name }
	
	/// Describes the operating capability of the port for inbound or outbound network traffic.
	public var portStatus: PortStatus {	runtime?.portStatus ?? .offline }
	
	///  The statistics for network traffic on this port.
	public var portMetrics: PortMetrics { runtime?.portMetrics ?? .init() }
	
	/// Controls whether the port may process network traffic.
	///
	/// The enablement of the port along with a valid value only offers permission
	/// to start the port, but does not make any guarantees about its operation.
	public var isEnabled: Bool {
		get { self.config.isEnabled }
		set { self.config.isEnabled = newValue }
	}
	
	/// Defines the local TCP port that will accept the protocol.
	public var value: NetworkPortValue? {
		get { self.config.value }
		set { self.config.value = newValue }
	}

	/// Defines a recommended default listening port value for the TCP port, provided by its configuration.
	public var defaultValue: NetworkPortValue? { self.config.defaultValue }
	
	/// The number of queued client requests that will be accepted by the port.  Defaults to `16`.
	public var clientBacklog: UInt16 {
		get { self.config.clientBacklog }
		set { self.config.clientBacklog = newValue }
	}
}

/*
 *  Internal.
 */
extension RRFirewallPort {
}
