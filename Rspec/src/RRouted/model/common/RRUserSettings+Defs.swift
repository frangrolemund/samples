//
//  RRUserSettings+Defs.swift
//  RRouted
// 
//  Created on 12/4/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import RREngine

//  DESIGN:  I decided to save all settings in Application support over the UserDefaults
// 			 beause it seemed like Apple was moving away from that in favor of the app
//			 sandbox since there are new privacy requirements placed on saving to UserDefaults.
//  DESIGN:  Each of these two categories of setting are intentionally built to be very simple
//			 to extend, ideally without custom encoding.
//  DESIGN:  One approach below is the use of optionals for these properties so that the file
//			 is extensible without breaking in future additions.  Consider the upgrade path
// 			 at all times!

/*
 *  The document-specific user settings.
 */
struct RRDocumentUserSettings : Codable {
	var hasAuthorizedFirewall: Bool?
	var firewallSettings: RRFirewallSettings?
	
	init() {
		self.hasAuthorizedFirewall = false
		self.firewallSettings 	   = nil
	}
}

/*
 *  The app-wide user settings.
 */
struct RRGlobalUserSettings : Codable {
	var authorIdentifier: RRIdentifier
	var hasSeenFirewallConfiguration: Bool?
	
	init() {
		authorIdentifier 		     = .init()
		hasSeenFirewallConfiguration = nil
	}
}
