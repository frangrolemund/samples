//
//  FirewallPopover+PortDisplay.swift
//  RRouted
// 
//  Created on 11/25/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine

/*
 *  The display and editing of the port settings.
 */
struct FirewallPopoverPortDisplayView : View {
	private let name: String
	private let status: Status
	private let isModified: Bool
	@Binding private var settings: RRFirewallPortSettings
	private let conflictError: RRMultiFirewallCoordinator.ConflictError?
	private let applyAction: RRUIAction?
	private let cancelAction: RRUIAction?
	
	/*
	 *  Initialize the object.
	 */
	init(name: String, 
		 settings: Binding<RRFirewallPortSettings>,
		 status: RRFirewallPort.PortStatus,
		 isModified: Bool,
		 conflict: RRMultiFirewallCoordinator.ConflictError? = nil,
		 applyAction: RRUIAction?  = nil,
		 cancelAction: RRUIAction? = nil) {
		self.name          = name
		self._settings     = settings
		self.status        = .from(status)
		self.isModified    = isModified
		self.conflictError = conflict
		self.applyAction   = applyAction
		self.cancelAction  = cancelAction
	}
	
	var body: some View {
		VStack {
			HStack(spacing: 0) {
				let color: Color = isModified ? .accentColor : .secondary
				Text("\(name) Port")
					.font(.body)
					.fontWeight(.bold)
					.foregroundStyle(.secondary)
					.overlay(alignment: .topLeading) {
						if isModified {
							Text("*")
								.fontWeight(.bold)
								.foregroundStyle(color)
								.offset(.init(width: -10, height: -2))
						}
					}
				
				ZStack {
					ProgressView()
						.scaleEffect(0.4)
						.help("Reconfiguring")
						.hidden(isHidden: status != .pending )
						.frame(width: 5, height: 5)
					
					FirewallStatusIndicatorView(status.asPortStatus ?? .offline)
						.hidden(isHidden: status == .pending)
				}
				.padding(.init(top: 0, leading: 10, bottom: 0, trailing: 0))
				
				Spacer()
			}
			.font(.title3)
			
			Grid(alignment: .leading, verticalSpacing: 10) {
				GridRow(alignment: .center) {
					Text("Enabled")
					
					Toggle(isOn: $settings.isEnabled, label: {
						Text("")
					})
					.toggleStyle(.checkbox)
					.offset(.init(width: 0, height: -2))
					
					Spacer()
				}
				
				let conflictHelp = self.conflictHelp
				GridRow(alignment: .center) {
					Text("Port Number")
						.foregroundStyle((conflictHelp == nil) ? Color.primary : Color.red)
						.help(conflictHelp ?? "")

					NetworkPortNumberTextField(value: $settings.value)
						.frame(width: 100)
						.help(conflictHelp ?? "")
					
					Spacer()
				}
				
				GridRow(alignment: .center) {
					Text("Client Backlog")
					NetworkClientBacklogTextField(value: $settings.clientBacklog)
						.frame(width: 100)
					
					Spacer()
				}
			}
			.font(.subheadline)
			.padding(.init(top: 0, leading: 5, bottom: 0, trailing: 0))
			
			if isModified {
				EqualWidthsHStack {
					FirewallPopoverTextButton(text: "Cancel",
											  asProminent: false,
											  allowSizing: true) {
						guard let cancelAction = cancelAction else {
							return
						}
						cancelAction()
					}

					FirewallPopoverTextButton(text: "Apply Changes",
											  asProminent: true,
											  allowSizing: true) {
						guard let applyAction = applyAction else {
							return
						}
						applyAction()
					}
					.disabled(conflictError != nil)
				}
				.padding(.init(top: 10, leading: 0, bottom: 0, trailing: 0))
			}
		}
		.padding(.init(top: 0, leading: 2, bottom: 0, trailing: 0))
	}
}

/*
 *  Internal.
 */
extension FirewallPopoverPortDisplayView {
	private enum Status : Equatable {
		case terminal(status: RRFirewallPort.PortStatus)
		case pending
		
		var asPortStatus: RRFirewallPort.PortStatus? {
			if case .terminal(let status) = self {
				return status
			}
			return nil
		}
		
		static func from(_ status: RRFirewallPort.PortStatus) -> Status {
			switch status {
			case .online, .degraded, .offline, .error(_):
				return .terminal(status: status)
				
			default:
				return .pending
			}
		}
	}
	
	private var conflictHelp: LocalizedStringKey? {
		guard let conflictError = conflictError else { return nil }
		switch conflictError {
		case .appliedConflict(let sameDocument):
			return sameDocument ? .init("The port number conflicts with another configured port.") :
								  .init("The port number conflicts with a configured port in another document.")
			
		case .pendingConflict:
			return .init("The port number conflicts with a pending change.")
		}
	}
}

/*
 *  Preview the port types.
 */
#Preview {
	VStack {
		FirewallPopoverPortDisplayView(name: "Sample Port", settings: .constant(.init(id: .init(), isEnabled: true, clientBacklog: 14)), status: .online, isModified: false)
			.previewDevice(PreviewDevice(rawValue: "Mac"))
			.padding()
		
		Subdivider()
		
		FirewallPopoverPortDisplayView(name: "Modified Port", settings: .constant(.init(id: .init(), isEnabled: true, value: 1900, clientBacklog: 8)), status: .reconfiguring, isModified: true)
			.previewDevice(PreviewDevice(rawValue: "Mac"))
			.padding()
		
		Subdivider()
		
		FirewallPopoverPortDisplayView(name: "Conflict Port", settings: .constant(.init(id: .init(), isEnabled: true, value: 1900, clientBacklog: 8)), status: .offline, isModified: true,
			  conflict: .appliedConflict(sameDocument: true))
			.previewDevice(PreviewDevice(rawValue: "Mac"))
			.padding()
	}
	.frame(width: 250)
}
