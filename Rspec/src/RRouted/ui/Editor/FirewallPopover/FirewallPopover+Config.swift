//
//  FirewallPopover+Config.swift
//  RRouted
// 
//  Created on 10/3/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine

/*
 *  This presents the firewall configuration panel in the firewall popover.
 */
struct FirewallPopoverConfigView: View {
	private let document: RRoutedDocument
	@ObservedObject private var firewall: RRFirewall
	@State private var isFirewallEnabled: Bool

	/*
	 *  Initialize the object.
	 */
	init(document: RRoutedDocument) {
		self.document 		   = document
		self.firewall 		   = document.engine.firewall
		self.isFirewallEnabled = document.engine.firewall.isEnabled
	}
	
    var body: some View {
		VStack {
			Group {
				ZStack {
					Text("Firewall Configuration")
						.font(.title2)
						.fontWeight(.medium)

					HStack {
						Spacer()
						FirewallStatusIndicatorView(self.firewall.firewallStatus)
					}
				}
				
				HStack(alignment: .center) {
					Toggle("Allow Networking", isOn: $isFirewallEnabled)
						.toggleStyle(.switch)
					
					Spacer()
				}
				.onChange(of: isFirewallEnabled, perform: { newValue in
					self.firewall.isEnabled 								   = newValue
					self.document.settings.firewallSettings?.isFirewallEnabled = newValue
				})
				
				Divider()
					.padding(.init(top: 0, leading: 0, bottom: 5, trailing: 0))
			}
			.padding(.init(top: 15, leading: 15, bottom: 0, trailing: 15))
			.background {
				GeometryReader(content: { geometry in
					Color.clear.preference(key: EditorViewFirewallToolbar.FirewallPopoverSectionHeight.self, value: geometry.size.height)
				})
			}
			
			ScrollView(.vertical, showsIndicators: true) {
				Group {
					VStack(alignment: .leading) {
						let portList = self.displayPorts
						if portList.isEmpty {
							Text("No ports are defined.").foregroundStyle(Color.secondary)
								.padding(.init(top: 2, leading: 0, bottom: 0, trailing: 0))
						}
						else {
							VStack {
								ForEach(portList) { displayPort in
									VStack {
										FirewallPopoverPortView(document: document, 
																port: displayPort.port,
																displayName: displayPort.displayName)
										if displayPort.id != portList.last?.id {
											Subdivider()
												.padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
										}
									}
								}
							}
						}
					}
					Spacer()
				}
				.padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
				.background {
					GeometryReader { geometry in
						Color.clear.preference(key: EditorViewFirewallToolbar.FirewallPopoverSectionHeight.self, value: geometry.size.height)
					}
				}
			}
		}
		.frame(minHeight: 200)
		.id(self.firewall.portHash)
		.onDisappear {
			self.document.resetModifiedPortSettings()
		}
    }
}

/*
 *  Internal.
 */
extension FirewallPopoverConfigView {
	private struct DisplayedPort : Identifiable {
		var id: RRIdentifier { port.id }
		let port: RRFirewallPort
		let displayName: String
	}
	
	// - return the list of sorted ports.
	private var sortedPorts: [RRFirewallPort] {
		// ...for now the sorting is simply deterministic, but not
		//    significant to the user.  that can change later.
		return document.engine.firewall.ports.sorted(by: {$0.id.uuidString < $1.id.uuidString})
	}
	
	/*
	 *  Return the list of ports that will be used for display.
	 */
	private var displayPorts: [DisplayedPort] {
		let sPorts = self.sortedPorts
		
		var inUseNames: [String : Int] = [:]
		var ret: [DisplayedPort] 	   = []
		
		for p in sPorts {
			let dName: String
			let name = p.name ?? "Firewall Port"
			if let curCount = inUseNames[name] {
				let newCount	 = curCount + 1
				dName 		 	 = "\(name) (\(newCount))"
				inUseNames[name] = newCount
			}
			else {
				inUseNames[name] = 1
				dName			 = name
			}
			ret.append(.init(port: p, displayName: dName))
		}
		
		return ret
	}
}
