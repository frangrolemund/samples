//
//  FirewallPopover+Port.swift
//  RRouted
// 
//  Created on 11/13/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine
import Combine

/*
 *  Provides an editing experience for the settings of a single port in the firewall configuration.
 */
struct FirewallPopoverPortView: View {
	let document: RRoutedDocument
	@ObservedObject private var port: RRFirewallPort
	let displayName: String
	@State private var portSettings: RRFirewallPortSettings
	@ObservedObject private var coordinator: RRMultiFirewallCoordinator			// ...so that any coordinated modifications force validation
	
	/*
	 *  Initialize the object, but separate into a list of settings
	 *  and the original port which will communicate status.
	 */
	init(document: RRoutedDocument, port: RRFirewallPort, displayName: String) {
		self.document	   = document
		self.port		   = port
		self.displayName   = displayName
		self._portSettings = .init(wrappedValue: document.currentFirewallSettings().portSettings(for: port))
		self.coordinator   = document.firewallCoordinator
	}
	
	// - the structure of the view.
    var body: some View {
		let curSettings = document.currentFirewallSettings()
		let isModified  = curSettings.portSettings(for: port) != portSettings
		FirewallPopoverPortDisplayView(name: displayName, 
									   settings: $portSettings,
									   status: port.portStatus,
									   isModified: isModified,
									   conflict: self.document.validateModifiedPortSettings(portSettings)) {
			self.document.applyPortSettings(portSettings, to: port)
		} cancelAction: {
			portSettings = port.asUserSettings()
		}
		.onChange(of: portSettings, perform: { newValue in
			self.document.trackModifiedPortSettings(newValue)
		})
    }
}
