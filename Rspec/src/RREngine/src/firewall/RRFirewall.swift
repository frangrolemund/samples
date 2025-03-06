//
//  RRFirewall.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine
import CryptoKit

///  Controls and organizes the engine's interaction with the local network.
///
///  This firewall provides precise management over the external network ports
///  that are opened on the user's behalf. All actions will be explicitly authorized
///  and easily monitored by the hosting application to align its behavior to user
///  preferences.
///
///  The design of the engine networking requires that when it is initialized
///  or reloaded, the hosting app must affirm the configuration the firewall
///  interfaces used by the services.  Although some configuration may be saved
///  in the repo for this purpose, the final port assignment and enablement is not
///  and must be explicitly assigned in order for the network to come online.  The
///  ommission of explicit firewall configuration results in the equivlant of a
///  network segmentation where all engine behavior is inacessible outside the
///  hosting application.
@MainActor
public final class RRFirewall : RRDynamo, RRUIPresentable {
	override nonisolated class var logCategory: String? { "Firewall" }
	override var shutdownDescriptor: String? { "firewall" }
	
	/// Generates a firewall preview.
	///
	/// - Parameter type: Only a single preview type is supported.
	public static func preview(ofPreviewType previewType: Void? = nil) -> RRFirewall {
		return RRFirewall(in: .init())
	}
	
	/*
	 *  Initialize the object.
	 */
	nonisolated init(in environment: RREngineEnvironment) {
		super.init(with: Config(), in: environment)
	}
	
	/*
	 *  The engine's pause status was modified.
	 */
	override nonisolated func dynamoWasPaused(isPaused: Bool) {
		super.dynamoWasPaused(isPaused: isPaused)
		//  DESIGN:  The firewall doesn't act upon or report a paused
		//			 status because it's purpose is to manage network
		//			 access specifiacally.  It should be assume that
		//			 when paused, the firewall is offline.
	}
}

/*
 *  Types.
 */
extension RRFirewall : RRStaticDynamoInternal {
	///  Describes the capacity of the firewall to allow networking.
	public enum FirewallStatus {
		/// The firewall and/or its ports are all disabled and will not pass networking traffic.
		case offline
				
		/// The firewall and/or its ports are misconfigured and may not process all traffic.
		case warning
		
		/// The firewall and all of its ports are misconfigured and may not process traffic.
		case error
		
		/// The firewall is operating correctly and can accept networking traffic.
		case online
	}
	
	struct Config : RRDynamoConfigurable {
		var isEnabled: Bool
		
		// - initialize the value
		init() {
			isEnabled = true
		}
	}
	
	struct State : RRStaticDynamoStateful {
		var portHash: String?
		var ports: [RRFirewallPort] = []
		var portMap: [RRIdentifier : RRFirewallPort] = [:]
		func shutdown() async -> RRShutdownResult {
			var result: RRShutdownResult = .success
			for p in ports {
				result.append(await p.shutdown())
			}
			return result
		}
	}
	
	/*
	 *  Build the firewall state.
	 */
	func buildState() -> State { .init() }
}

/*
 *  Acceessors
 */
extension RRFirewall {
	/// Controls whether the firewall may process network traffic.
	///
	/// The enablement of the firewall only offers permission to start its ports,
	/// but does not make any guarantees about its operation.  The `state` is used
	/// to accurately establish its operating behavior.
	nonisolated public var isEnabled: Bool {
		get { config.isEnabled }
		set { config.isEnabled = newValue }
	}
	
	/// The processing behavior of the firewall.
	public var operatingStatus: RROperatingStatus { self.__operatingStatus }
		
	/// The local-network ports that may receive requests into the system flow.
	public var ports: [RRFirewallPort] { self.state?.ports ?? [] }
	
	/// Find a local-network port by identifier.
	public func port(for id: RRIdentifier) -> RRFirewallPort? { self.state?.portMap[id]	}
	
	/// A hash representing the the identity of all configured ports in the firewall.
	public var portHash: String { self.state?.portHash ?? [RRFirewallPort].init().portHash }
	
	/// The capacity of the firewall to accept and process networking traffic.
	public var firewallStatus: FirewallStatus {
		let ports = self.ports
		guard isEnabled, !ports.isEmpty else { return .offline }
		
		var numOnline: Int  = 0
		var numInvalid: Int = 0
		var numError: Int 	= 0
		for p in ports {
			if !p.isEnabled {
				continue
			}

			switch p.portStatus {
			case .online:
				numOnline += 1
				
			case .error(_):
				numError  += 1
					
			case .degraded, .offline:
				numInvalid += 1
				
			default:
				continue
			}
		}
		
		if numOnline == ports.count {
			return .online
		}
		else if numError == ports.count {
			return .error
		}
		else if (numInvalid > 0 || numOnline > 0), !self.environment.isEnginePaused {
			return .warning
		}
		else {
			return .offline
		}
	}
}

/*
 *  Internal.
 */
extension RRFirewall {
	/*
	 *  Build a port configuration in the firewall that will direct traffic
	 *  to the provided trigger node.
	 *  DESIGN: This is internal and intended to be called by a trigger node to enable traffic
	 *  	 	to a specific destination.
	 */
	nonisolated func connectPort(ofType protocolType: RRNetworkProtocol,
								 withDefaultValue defaultValue: NetworkPortValue? = nil,
								 toTrigger triggerNode: RRDebugTriggerNode) {
		// - build a port with default attributes, linking it to its trigger node by
		//   the node's identifier.
		let newPort: RRFirewallPort
		switch protocolType {
		case .http:
			let config = RRHTTPFirewallPort.Config(id: triggerNode.id, isEnabled: true, defaultValue: defaultValue)
			newPort    = RRHTTPFirewallPort(withFirewall: self, andConfig: config)
		}

		// - ports are saved in the state, but are treated as part of the model
		self.runtimeStateWillChangeModel()
		self.withLock {
			guard var ports = self.state?.ports, var portMap = self.state?.portMap else { return }
			ports.append(newPort)
			portMap[newPort.id]  = newPort
			self.state?.ports    = ports
			self.state?.portMap  = portMap
			self.state?.portHash = ports.portHash
		}
	}
}

/*
 *  Utitlities.
 */
public extension Array where Element: RRFirewallPort {
	/// Return a unique hash representing the port identifications in the array to be able
	/// to quickly and cheaply determine if the external understanding of the ports matches
	/// the configured list.
	var portHash: String {
		let sIds = self.map({$0.id.uuidString}).sorted(by: {$0 < $1}).joined(separator: ".")
		
		let digest: SHA256Digest
		if let data = sIds.data(using: .utf8) {
			digest = SHA256.hash(data: data)
		}
		else {
			digest = SHA256.hash(data: Data(count: 1))
		}
		return digest.compactMap { String(format: "%02x", $0) }.joined()
	}
}
