//
//  RRoutedDocument+APIs.swift
//  RRouted
// 
//  Created on 11/11/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import RREngine

/*
 *  Document-related utilities.
 */
extension RRoutedDocument {
	/*
	 *  Returns the current list of settings for the firewall.
	 */
	@MainActor
	func currentFirewallSettings() -> RRFirewallSettings {
		// - use the port hash to determine if we have everything we need.
		let curSettings = self.settings.firewallSettings
		if let cs = curSettings, cs.lastPortHash == self.engine.firewall.portHash {
			return cs
		}

		// - the port hash is different so we'll need to synchronize what we have
		//   and re-save them before returning.
		var newSettings = self.engine.firewall.currentSettings()
		
		// - sync if they existed
		if let cs = curSettings {
			newSettings.isFirewallEnabled = cs.isFirewallEnabled
			for cps in cs.portSettings {
				guard let idx = newSettings.portSettings.firstIndex(where: {$0.id == cps.id}) else { continue }
				
				var nps = newSettings.portSettings[idx]
				
				// - ok, reconcile the saved content to up[date the new port
				nps.isEnabled     = cps.isEnabled
				nps.value	      = cps.value
				nps.clientBacklog = cps.clientBacklog
				
				// - re-save
				newSettings.portSettings[idx] = nps
			}
		}
		
		// - save in the settings and return
		self.settings.firewallSettings = newSettings		
		return newSettings
	}
	
	/*
	 *  Watch modified port settings across documents.
	 */
	@MainActor
	func trackModifiedPortSettings(_ settings: RRFirewallPortSettings) {
		self.firewallCoordinator.trackModifiedPortSettings(settings, in: self)
	}
	
	/*
	 *  Clear any pending modifications for the given document.
	 */
	@MainActor
	func resetModifiedPortSettings() {
		self.firewallCoordinator.resetModifiedPortSettings(for: self)
	}
	
	/*
	 *  Validate the pending port changes.
	 */
	@MainActor
	func validateModifiedPortSettings(_ settings: RRFirewallPortSettings) -> RRMultiFirewallCoordinator.ConflictError? {
		self.firewallCoordinator.validateModifiedPortSettings(settings, in: self)
	}
	
	/*
	 *  Apply settings to the specified port.
	 */
	@MainActor
	func applyPortSettings(_ settings: RRFirewallPortSettings, to port: RRFirewallPort) {
		var fwSettings = self.currentFirewallSettings()
		guard let idx = fwSettings.portSettings.firstIndex(where: {$0.id == settings.id}) else { return }
		fwSettings.portSettings[idx] = settings
		port.applySettings(settings)
		self.settings.firewallSettings = fwSettings
	}
}
