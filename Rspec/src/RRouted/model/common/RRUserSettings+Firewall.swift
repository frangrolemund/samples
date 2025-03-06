//
//  RRUserSettings+Firewall.swift
//  RRouted
// 
//  Created on 11/11/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import RREngine


/*
 *  Defines all the settings for the firewall if it is
 *  enabled.
 */
struct RRFirewallSettings : Codable, Equatable {
	var isFirewallEnabled: Bool
	var portSettings: [RRFirewallPortSettings]
	let lastPortHash: String
	
	@MainActor
	func portSettings(for port: RRFirewallPort) -> RRFirewallPortSettings {
		return portSettings.first { $0.id == port.id } ?? port.asUserSettings()
	}
}

/*
 *  Defines the persistent settings for a firewall port that
 *  are used to configure it explicitly from the app during
 *  startup or reconfiguration.
 *  DESIGN:  These are built to be port-type agnostic and mirror
 *  		 all of the supported port type configuration items.
 */
struct RRFirewallPortSettings : Codable, Equatable, Identifiable {
	let id: RRIdentifier
	var isEnabled: Bool
	var value: NetworkPortValue?
	var clientBacklog: UInt16
}

/*
 *  Utilities.
 */
extension RRFirewall {
	/*
	 *  Generate a copy of the current settings in the firewall.
	 */
	func currentSettings() -> RRFirewallSettings {
		var portSettings: [RRFirewallPortSettings] = []
		let curPorts = self.ports		// take a copy so that it is a snapshot of the values and the hash matches.
		for p in curPorts {
			portSettings.append(p.asUserSettings())
		}
		return .init(isFirewallEnabled: self.isEnabled, portSettings: portSettings, lastPortHash: curPorts.portHash)
	}
}

/*
 *  Utilities.
 */
extension RRFirewallPort {
	/*
	 *  Generate user settings for a single port.
	 */
	func asUserSettings() -> RRFirewallPortSettings {
		RRFirewallPortSettings(id: self.id,
							   isEnabled: self.isEnabled,
							   value: self.value,
							   clientBacklog: self.clientBacklog)
	}
	
	/*
	 *  Apply user settings to the firewall port.
	 */
	func applySettings(_ settings: RRFirewallPortSettings) {
		self.isEnabled	   = settings.isEnabled
		self.value 		   = settings.value
		self.clientBacklog = settings.clientBacklog
	}
}
