//
//  FirewallPopover+Permissions.swift
//  RRouted
// 
//  Created on 10/3/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  This presents a geneneral-purpose permissions panel in the firewall
 *  popover to require the user to approve the use of networking in each
 *  document.
 */
struct FirewallPopoverPermissionsView: View {
	private let settings: RRUserSettings
	init(settings: RRUserSettings) {
		self.settings = settings
	}
	
    var body: some View {
		VStack {
			Text("Firewall Configuration")
				.font(.title2)
				.fontWeight(.medium)

			HStack {
				VStack(alignment: .leading) {
					Text("This app provides TCP networking support that allows client program interaction with your custom data flows and processing.")
					Text("")
					Text("Before network connectivity is available in this document, you must first enable and minimally configure its _firewall_ to ensure its behavior meets your expectations.")
					
					HStack {
						Spacer()
						FirewallPopoverTextButton(text: "Allow Networking") {
							withAnimation {
								settings.hasAuthorizedFirewall = true
							}
						}
						Spacer()
					}
					.padding(.init(top: 10, leading: 0, bottom: 0, trailing: 0))
				}
			}
			.padding(.init(top: 5, leading: 0, bottom: 10, trailing: 0))
		}
    }
}

#Preview {
	FirewallPopoverPermissionsView(settings: .preview())
		.frame(width: 300)
}
