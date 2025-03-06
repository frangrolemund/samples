//
//  FirewallIndicatorView.swift
//  RRouted
// 
//  Created on 11/7/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine

/*
 *  Displays the status of the firewall.
 */
struct FirewallStatusIndicatorView: View {
	private var status: OperatingIndicatorView.IndicatorStatus
	
	/*
	 *  Initialize the view.
	 */
	init(_ status: OperatingIndicatorView.IndicatorStatus = .disabled) {
		self.status = status
	}
	
	/*
	 *  Initialize the view from a firewall status.
	 */
	init(_ fStatus: RRFirewall.FirewallStatus = .offline) {
		let iStatus: OperatingIndicatorView.IndicatorStatus
		switch fStatus {
		case .offline:
			iStatus = .disabled

		case .warning:
			iStatus = .warning
			
		case .error:
			iStatus = .error

		case .online:
			iStatus = .ok
		}
		self.init(iStatus)
	}
	
	/*
	 *  Initialize the view from a port status.
	 */
	init(_ pStatus: RRFirewallPort.PortStatus = .offline) {
		let iStatus: OperatingIndicatorView.IndicatorStatus
		switch pStatus {
		case .online:
			iStatus = .ok
			
		case .degraded:
			iStatus = .warning
			
		case .offline:
			iStatus = .disabled
			
		case .error(_):
			iStatus = .error
			
		default:
			iStatus = .disabled
		}
		
		self.init(iStatus)
	}
		
	// - the content
    var body: some View {
		let helpText: LocalizedStringKey
		switch status {
		case .disabled:
			helpText = RRouted.localization.offline

		case .warning:
			helpText = RRouted.localization.degraded
			
		case .error:
			helpText = RRouted.localization.error

		case .ok:
			helpText = RRouted.localization.online
		}
				
        return OperatingIndicatorView(indicatorStatus: status)
			.help(helpText)
    }
}

#Preview {
	HStack {
		FirewallStatusIndicatorView(OperatingIndicatorView.IndicatorStatus.disabled)
		FirewallStatusIndicatorView(OperatingIndicatorView.IndicatorStatus.warning)
		FirewallStatusIndicatorView(OperatingIndicatorView.IndicatorStatus.error)
		FirewallStatusIndicatorView(OperatingIndicatorView.IndicatorStatus.ok)
	}
}
