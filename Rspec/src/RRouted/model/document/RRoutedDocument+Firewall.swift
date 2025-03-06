//
//  RRoutedDocument+Firewall.swift
//  RRouted
// 
//  Created on 12/2/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import RREngine

/*
 *  Coordinates changes to firewalls across documents in the UI.
 *  DESIGN: The changes to port values is a tricky operation when
 *   		it works perfectly, but could be really annoying to
 * 	 		debug if there was more than one document open which I
 *  		thought might warrant a more precise type of contextual
 * 			error for the user.
 */
@MainActor
class RRMultiFirewallCoordinator : ObservableObject {
	/*
	 *  Initialize the object.
	 */
	init() {
		self.configs = []
	}
	
	/*
	 *  Save a firewall to reference for coordination.
	 */
	func register(document: RRoutedDocument) {
		self.configs.append(.init(firewall: document.engine.firewall))
		
		// - the main thing we're watching are updates to the port settings
		//   during modification.
		let curSettings = document.currentFirewallSettings()
		for ps in curSettings.portSettings {
			trackModifiedPortSettings(ps, in: document)
		}
	}
	
	/*
	 *  Save modified settings for a specific port.
	 */
	func trackModifiedPortSettings(_ settings: RRFirewallPortSettings, in document: RRoutedDocument) {
		let fwId = document.engine.firewall.id
		
		// - minimize changes to the published value to not generate spurious events, but
		//   process the full array if the same firewall is registered more than once.
		var hasInvalid: Bool = false
		for i in 0..<configs.count {
			var c = configs[i]
			hasInvalid = hasInvalid || (c.firewall.operatingStatus != .running)
			guard c.firewall.id == fwId, settings.value != c.portSettings[settings.id] else { continue }
			c.portSettings[settings.id] = settings.value
			configs[i] 					= c
		}
		
		if hasInvalid {
			configs = configs.filter({$0.firewall.operatingStatus == .running})
		}
	}
	
	/*
	 *  Reset the settings in a specific document.
	 */
	func resetModifiedPortSettings(for document: RRoutedDocument) {
		if let cIdx = configs.firstIndex(where: {$0.firewall.id == document.engine.firewall.id}) {
			configs[cIdx].portSettings.removeAll()
		}
	}
	
	enum ConflictError : Error {
		case appliedConflict(sameDocument: Bool)		// - a conflict with an in-use port
		case pendingConflict							// - a conflict with a pending modification in the current document
	}
	
	/*
	 *  Check that a port value doesn't conflict with anything else.
	 */
	func validateModifiedPortSettings(_ settings: RRFirewallPortSettings, in document: RRoutedDocument) -> ConflictError? {
		let fwId = document.engine.firewall.id
		
		// - only makes sense to validate an actual value
		if let pValue = settings.value {
			// ...show conflicts in current document first
			if let c = configs.first(where: {$0.firewall.id == fwId}),
			   let err = c.validatePortValue(port: settings.id, value: pValue, sameDocument: true) {
				return err
			}
			
			// ...then in other documents.
			for c in configs {
				guard c.firewall.id != fwId else { continue }
				if let err = c.validatePortValue(port: settings.id, value: pValue, sameDocument: false) {
					return err
				}
			}
		}

		// - no error.
		return nil
	}
	
	// - organize by firewall to support contextual validation errors.
	@MainActor
	private struct FirewallConfiguration {
		let firewall: RRFirewall
		var portSettings: [RRIdentifier : NetworkPortValue?] = [:]

		/*
		 *  Validate a specific configuration
		 */
		func validatePortValue(port portId: RRIdentifier, value: NetworkPortValue, sameDocument: Bool) -> RRMultiFirewallCoordinator.ConflictError? {
			if let _ = firewall.ports.first(where: {$0.id != portId && $0.value == value}) {
				return .appliedConflict(sameDocument: sameDocument)
			}

			for (k, v) in portSettings {
				guard k != portId, v == value else { continue }
				return .pendingConflict
			}
			
			return nil
		}
	}
	
	@Published private var configs: [FirewallConfiguration]
}
