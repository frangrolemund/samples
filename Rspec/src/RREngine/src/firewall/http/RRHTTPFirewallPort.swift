//
//  RRHTTPFirewallPort.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  Manages a local network-accessible HTTP protocol ingress for the engine.
@MainActor
public final class RRHTTPFirewallPort : RRFirewallPort {
	override class var logCategory: String? { "FirewallHTTPPort" }
	override var shutdownDescriptor: String? {
		if let url = self.config.targetURL?.absoluteString, self.portStatus == .online {
			return "HTTP port \(url) (\(config.id.briefId))"
		}
		else {
			return "HTTP port \(config.id.briefId)"
		}
	}
	
	/*
	 *  Initialize the object.
	 */
	nonisolated init(withFirewall firewall: RRFirewall, andConfig config: Config) {
		super.init(withFirewall: firewall, andConfig: config)
	}
}

/*
 *  Types.
 */
extension RRHTTPFirewallPort : RRFirewallPortInternal {
	struct Config : RRFirewallPortConfigurable {
		static let controllerType = RRHTTPFirewallPortController.self
		
		var portType: RRNetworkProtocol { .http }
		var id: RRIdentifier
		var isEnabled: Bool
		var value: NetworkPortValue?
		var defaultValue: NetworkPortValue?
		var clientBacklog: UInt16
		var reuseAddr: Bool
		
		var targetURL: URL? {
			guard let value = value else { return nil }
			return URL(string: "http://localhost:\(value)")
		}

		/*
		 *  Initialize the object
		 */
		init(id: RRIdentifier = .init(),
			 isEnabled: Bool,
			 value: NetworkPortValue? = nil,
			 defaultValue: NetworkPortValue? = nil,
			 clientBacklog: UInt16 = Self.DefaultClientBacklog,
			 reuseAddr: Bool = true) {
			self.id 					= id
			self.isEnabled 				= isEnabled
			self.value 					= value
			self.defaultValue 			= defaultValue
			self.clientBacklog 			= clientBacklog
			self.reuseAddr 				= reuseAddr
		}

		/*
		 *  Initialize the object.
		 */
		init() {
			self.init(isEnabled: true)
		}
	}
}
